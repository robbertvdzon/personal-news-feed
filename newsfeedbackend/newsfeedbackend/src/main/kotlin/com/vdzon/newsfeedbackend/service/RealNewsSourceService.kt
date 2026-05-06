package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.CategoryResult
import com.vdzon.newsfeedbackend.model.CategorySettings
import com.vdzon.newsfeedbackend.model.NewsItem
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import java.time.Instant
import java.time.LocalDate
import java.util.UUID

data class DailyFetchResult(
    val items: List<NewsItem>,
    val categoryResults: List<CategoryResult>,
    val totalCostUsd: Double
)

data class FeedbackContext(
    val likedTitles: List<String> = emptyList(),
    val dislikedTitles: List<String> = emptyList(),
    /** Geformatteerde topic-geschiedenis voor de selectie-prompt */
    val topicHistoryContext: String = ""
)

private val SYSTEM_CATEGORY_IDS = setOf("overig")

@Service
class RealNewsSourceService(
    private val tavilyService: TavilyService,
    private val anthropicService: AnthropicService,
    private val rssFetchService: RssFetchService
) {
    private val log = LoggerFactory.getLogger(RealNewsSourceService::class.java)

    fun fetchDailyNews(
        categories: List<CategorySettings>,
        rssUrls: List<String> = emptyList(),
        feedback: FeedbackContext = FeedbackContext(),
        onArticle: (NewsItem) -> Unit = {}
    ): DailyFetchResult {
        log.info("Fetch daily news, START")

        val allItems = mutableListOf<NewsItem>()
        val categoryResults = mutableListOf<CategoryResult>()
        var totalCost = 0.0

        val enabledCategories = categories.filter { it.enabled && !it.isSystem && it.id !in SYSTEM_CATEGORY_IDS }

        // Fetch all RSS articles once
        val allRssArticles = rssFetchService.fetchAll(rssUrls)
        log.info("RSS totaal: {} artikelen van {} feeds", allRssArticles.size, rssUrls.size)

        // Apply date filter (1 day)
        val filtered = filterByDate(allRssArticles, 1)
        log.info("RSS na datum-filter (1 dag): {} artikelen", filtered.size)

        // Track seen URLs for deduplication across categories
        val seenUrls = mutableSetOf<String>()

        // Process each enabled non-system category
        enabledCategories.forEach { cat ->
            log.info("Process categorie '{}'", cat.name)
            val available = filtered.filter { it.url !in seenUrls }
            log.info("Categorie '{}': {} beschikbaar na deduplicatie", cat.name, available.size)

            if (available.isEmpty()) {
                log.warn("Geen artikelen beschikbaar voor categorie '{}'", cat.name)
                return@forEach
            }

            log.info("Select articles for categorie '{}'", cat.name)
            val (items, cost) = selectExtractAndSummarize(
                articles = available,
                subject = cat.name,
                extraInstructions = cat.extraInstructions,
                preferredCount = cat.preferredCount,
                maxCount = cat.maxCount,
                categoryId = cat.id,
                feedback = feedback,
                onArticle = onArticle
            )
            log.info("{} articles are seclted for categorie '{}'",items.size,  cat.name)

            items.forEach { seenUrls.add(it.url) }
            allItems.addAll(items)
            totalCost += cost
            categoryResults.add(CategoryResult(
                categoryId = cat.id,
                categoryName = cat.name,
                articleCount = items.size,
                costUsd = cost,
                searchResultCount = filtered.size,
                filteredCount = available.size
            ))
            log.info("Categorie '{}': {} toegevoegd, kosten \${}",
                cat.name, items.size, "%.5f".format(cost))
        }

        // Dagelijks overzicht
        if (allItems.isNotEmpty()) {
            val categoryNames = enabledCategories.map { it.name }
            try {
                log.info("Dagelijks overzicht genereren op basis van {} artikelen", allItems.size)
                val (summaryItem, summaryCost) = anthropicService.generateDailySummary(allItems, categoryNames)
                allItems.add(0, summaryItem)
                onArticle(summaryItem)
                totalCost += summaryCost
                log.info("Dagelijks overzicht klaar, kosten \${}", "%.5f".format(summaryCost))
            } catch (e: Exception) {
                log.error("Dagelijks overzicht mislukt: {}", e.message)
            }
        }
        log.info("Fetch daily news, Finished")

        return DailyFetchResult(allItems, categoryResults, totalCost)
    }

    fun fetchArticlesForSubject(
        subject: String,
        preferredCount: Int,
        extraInstructions: String = "",
        maxAgeDays: Int = 3,
        categories: List<CategorySettings>,
        rssUrls: List<String> = emptyList(),
        feedback: FeedbackContext = FeedbackContext(),
        onArticle: (NewsItem) -> Unit = {}
    ): Pair<List<NewsItem>, Double> {
        val categoryId = detectCategory(subject, categories)

        // Fetch all RSS articles
        val allRssArticles = rssFetchService.fetchAll(rssUrls)
        log.info("RSS totaal voor '{}': {} artikelen", subject, allRssArticles.size)

        // Apply date filter
        val filtered = filterByDate(allRssArticles, maxAgeDays)
        log.info("RSS na datum-filter ({} dagen) voor '{}': {} artikelen", maxAgeDays, subject, filtered.size)

        if (filtered.isEmpty()) {
            log.warn("Geen RSS artikelen beschikbaar voor '{}'", subject)
            return Pair(emptyList(), 0.0)
        }

        return selectExtractAndSummarize(
            articles = filtered,
            subject = subject,
            extraInstructions = extraInstructions,
            preferredCount = preferredCount,
            maxCount = preferredCount,
            categoryId = categoryId,
            feedback = feedback,
            onArticle = onArticle
        )
    }

    // ── Selecteer → extract → vat samen ──────────────────────────────────────

    private fun selectExtractAndSummarize(
        articles: List<TavilySearchResult>,
        subject: String,
        extraInstructions: String,
        preferredCount: Int,
        maxCount: Int,
        categoryId: String,
        feedback: FeedbackContext,
        onArticle: (NewsItem) -> Unit
    ): Pair<List<NewsItem>, Double> {
        var totalCost = 0.0

        // Claude selecteert de meest relevante artikelen
        log.info("Using AI for finding articles")
        val (selectedIndices, selectionCost) = anthropicService.selectArticles(
            articles = articles,
            categoryName = subject,
            extraInstructions = extraInstructions,
            preferredCount = preferredCount,
            maxCount = maxCount,
            likedTitles = feedback.likedTitles,
            dislikedTitles = feedback.dislikedTitles,
            topicHistoryContext = feedback.topicHistoryContext
        )
        totalCost += selectionCost
        log.info("Selected ${selectedIndices.size} articles")

        if (selectedIndices.isEmpty()) {
            log.warn("Geen artikelen geselecteerd voor '{}'", subject)
            return Pair(emptyList(), totalCost)
        }

        // Tavily haalt volledige tekst op voor geselecteerde URLs
        val selectedResults = selectedIndices.map { articles[it] }
        log.info("Extract content using tavily")
        val extractedContent = tavilyService.extractContent(selectedResults.map { it.url })

        val publishedDateByUrl = selectedResults.associate { result ->
            result.url to (result.publishedDate ?: extractDateFromUrl(result.url))
        }.filterValues { it != null }.mapValues { it.value!! }

        // Gebruik volledige tekst indien beschikbaar, anders RSS snippet als fallback
        val tavilyArticles = selectedResults.map { result ->
            TavilyArticle(
                title   = result.title,
                url     = result.url,
                source  = result.source,
                content = extractedContent[result.url]?.takeIf { it.length > 200 } ?: result.snippet,
                feedUrl = result.feedUrl
            )
        }

        // Claude maakt een Nederlandse samenvatting per artikel
        val now = Instant.now().toString()
        val newsItems = mutableListOf<NewsItem>()

        tavilyArticles.forEach { article ->
            log.info("Start samenvatting voor '{}' ({})", article.title.take(40), subject)
            val (summarized, cost) = anthropicService.summarizeArticle(article, subject)
            val item = summarized.toNewsItem(categoryId, now, publishedDateByUrl[article.url])
            onArticle(item)
            newsItems.add(item)
            totalCost += cost
            log.info("Finished samenvatting voor '{}' ({})", article.title.take(40), subject)
        }

        return Pair(newsItems, totalCost)
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private fun detectCategory(subject: String, categories: List<CategorySettings>): String {
        val lc = subject.lowercase()
        return categories.firstOrNull { cat ->
            lc.contains(cat.id) || lc.contains(cat.name.lowercase())
        }?.id ?: "overig"
    }

    private fun filterByDate(results: List<TavilySearchResult>, maxAgeDays: Int): List<TavilySearchResult> {
        val cutoff = LocalDate.now().minusDays(maxAgeDays.toLong() + 1)
        return results.filter { result ->
            val pubDate = result.publishedDate ?: return@filter true
            try {
                val date = LocalDate.parse(pubDate.take(10))
                !date.isBefore(cutoff)
            } catch (_: Exception) { true }
        }
    }

    private fun extractDateFromUrl(url: String): String? {
        val patterns = listOf(
            Regex("""[/\-](\d{4})[/\-](\d{1,2})[/\-](\d{1,2})[/\-?#]"""),
            Regex("""[/\-](\d{4})[/\-](\d{1,2})[/\-](\d{1,2})$""")
        )
        for (pattern in patterns) {
            val match = pattern.find(url) ?: continue
            val (year, month, day) = match.destructured
            val y = year.toIntOrNull() ?: continue
            val m = month.toIntOrNull() ?: continue
            val d = day.toIntOrNull() ?: continue
            if (y in 2010..2030 && m in 1..12 && d in 1..31) {
                return "$year-${month.padStart(2, '0')}-${day.padStart(2, '0')}"
            }
        }
        return null
    }

    private fun SummarizedArticle.toNewsItem(
        category: String,
        timestamp: String,
        publishedDate: String? = null
    ) = NewsItem(
        id = UUID.randomUUID().toString(),
        title = title,
        summary = summary,
        url = url,
        category = category,
        timestamp = timestamp,
        source = source,
        publishedDate = publishedDate,
        feedUrl = feedUrl
    )
}
