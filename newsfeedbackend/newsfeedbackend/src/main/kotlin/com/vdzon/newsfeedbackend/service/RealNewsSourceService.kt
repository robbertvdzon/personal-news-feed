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

data class FetchAndSummarizeResult(
    val items: List<NewsItem>,
    val costUsd: Double,
    val searchResultCount: Int,
    val filteredCount: Int
)

data class FeedbackContext(
    val likedTitles: List<String> = emptyList(),
    val dislikedTitles: List<String> = emptyList(),
    /** Geformatteerde topic-geschiedenis voor de selectie-prompt */
    val topicHistoryContext: String = ""
)

private val SYSTEM_CATEGORY_IDS = setOf("overig")
private const val SEARCH_POOL_SIZE = 20   // Tavily max = 20 per call
private const val RSS_PREFERRED_COUNT = 5
private const val RSS_MAX_COUNT = 10

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
        val allItems = mutableListOf<NewsItem>()
        val categoryResults = mutableListOf<CategoryResult>()
        var totalCost = 0.0

        val enabledCategories = categories.filter { it.enabled && !it.isSystem && it.id !in SYSTEM_CATEGORY_IDS }
        val skipped = enabledCategories.filter { it.websites.isEmpty() }
        if (skipped.isNotEmpty()) {
            log.info("Categorieën overgeslagen (geen bronnen geconfigureerd): {}",
                skipped.joinToString { it.name })
        }
        val categoriesWithSources = enabledCategories.filter { it.websites.isNotEmpty() }

        // ── Tavily pipeline per categorie ─────────────────────────────────────
        categoriesWithSources.forEach { cat ->
            val result = fetchAndSummarize(
                subject = cat.name,
                extraInstructions = cat.extraInstructions,
                preferredCount = cat.preferredCount,
                maxCount = cat.maxCount,
                categoryId = cat.id,
                websites = cat.websites,
                feedback = feedback,
                searchDays = 1,
                onArticle = onArticle
            )
            allItems.addAll(result.items)
            totalCost += result.costUsd
            categoryResults.add(CategoryResult(
                categoryId = cat.id,
                categoryName = cat.name,
                articleCount = result.items.size,
                costUsd = result.costUsd,
                searchResultCount = result.searchResultCount,
                filteredCount = result.filteredCount
            ))
            log.info("Categorie '{}': {} gevonden, {} na filter, {} toegevoegd, kosten \${}",
                cat.name, result.searchResultCount, result.filteredCount, result.items.size,
                "%.5f".format(result.costUsd))
        }

        // ── RSS pipeline ──────────────────────────────────────────────────────
        if (rssUrls.isNotEmpty()) {
            try {
                log.info("RSS pipeline starten: {} feeds", rssUrls.size)
                val rssResult = fetchFromRssFeeds(
                    rssUrls = rssUrls,
                    categories = enabledCategories,
                    maxAgeDays = 1,
                    preferredCount = RSS_PREFERRED_COUNT,
                    maxCount = RSS_MAX_COUNT,
                    feedback = feedback,
                    onArticle = onArticle
                )
                if (rssResult.items.isNotEmpty()) {
                    allItems.addAll(rssResult.items)
                    totalCost += rssResult.costUsd
                    categoryResults.add(CategoryResult(
                        categoryId = "rss",
                        categoryName = "RSS Feeds",
                        articleCount = rssResult.items.size,
                        costUsd = rssResult.costUsd,
                        searchResultCount = rssResult.searchResultCount,
                        filteredCount = rssResult.filteredCount
                    ))
                    log.info("RSS: {} gevonden, {} na filter, {} toegevoegd, kosten \${}",
                        rssResult.searchResultCount, rssResult.filteredCount, rssResult.items.size,
                        "%.5f".format(rssResult.costUsd))
                }
            } catch (e: Exception) {
                log.error("RSS pipeline mislukt: {}", e.message)
            }
        }

        // ── Dagelijks overzicht ───────────────────────────────────────────────
        if (allItems.isNotEmpty()) {
            val categoryNames = (categoriesWithSources.map { it.name } +
                if (rssUrls.isNotEmpty()) listOf("RSS Feeds") else emptyList())
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
        val categoryWebsites = categories.firstOrNull { it.id == categoryId }?.websites ?: emptyList()

        // ── Tavily pipeline ───────────────────────────────────────────────────
        val tavilyResult = fetchAndSummarize(
            subject = subject,
            extraInstructions = extraInstructions,
            preferredCount = preferredCount,
            maxCount = preferredCount,
            categoryId = categoryId,
            websites = categoryWebsites,
            feedback = feedback,
            searchDays = maxAgeDays,
            onArticle = onArticle
        )
        log.info("Tavily voor '{}': {} gevonden, {} na filter, {} toegevoegd, kosten \${}",
            subject, tavilyResult.searchResultCount, tavilyResult.filteredCount,
            tavilyResult.items.size, "%.5f".format(tavilyResult.costUsd))

        var allItems = tavilyResult.items.toMutableList()
        var totalCost = tavilyResult.costUsd

        // ── RSS pipeline (aanvullend) ─────────────────────────────────────────
        if (rssUrls.isNotEmpty()) {
            try {
                log.info("RSS feeds raadplegen als aanvulling voor '{}'", subject)
                val rssArticles = rssFetchService.fetchAll(rssUrls)
                if (rssArticles.isNotEmpty()) {
                    val rssResult = selectExtractAndSummarize(
                        searchResults = rssArticles,
                        subject = subject,
                        extraInstructions = extraInstructions,
                        preferredCount = minOf(preferredCount, 3),
                        maxCount = preferredCount,
                        categoryId = categoryId,
                        feedback = feedback,
                        searchDays = maxAgeDays,
                        onArticle = onArticle
                    )
                    allItems.addAll(rssResult.items)
                    totalCost += rssResult.costUsd
                    log.info("RSS voor '{}': {} gevonden, {} na filter, {} toegevoegd",
                        subject, rssResult.searchResultCount, rssResult.filteredCount, rssResult.items.size)
                }
            } catch (e: Exception) {
                log.error("RSS aanvulling mislukt voor '{}': {}", subject, e.message)
            }
        }

        return Pair(allItems, totalCost)
    }

    // ── RSS fetch + select + summarize ────────────────────────────────────────

    private fun fetchFromRssFeeds(
        rssUrls: List<String>,
        categories: List<CategorySettings>,
        maxAgeDays: Int,
        preferredCount: Int,
        maxCount: Int,
        feedback: FeedbackContext,
        onArticle: (NewsItem) -> Unit
    ): FetchAndSummarizeResult {
        val allRssArticles = rssFetchService.fetchAll(rssUrls)
        if (allRssArticles.isEmpty()) {
            log.warn("Geen RSS artikelen opgehaald")
            return FetchAndSummarizeResult(emptyList(), 0.0, 0, 0)
        }
        log.info("RSS totaal: {} artikelen van {} feeds", allRssArticles.size, rssUrls.size)

        val categoryNames = categories.filter { !it.isSystem }.joinToString(", ") { it.name }
        val subject = "tech nieuws (onderwerpen: $categoryNames)"

        // Verzamel items met juiste categorie via de callback
        val capturedItems = mutableListOf<NewsItem>()
        val result = selectExtractAndSummarize(
            searchResults = allRssArticles,
            subject = subject,
            extraInstructions = "",
            preferredCount = preferredCount,
            maxCount = maxCount,
            categoryId = "overig",  // tijdelijk; wordt hieronder per artikel bepaald
            feedback = feedback,
            searchDays = maxAgeDays,
            onArticle = { item ->
                val detectedCategory = detectCategory(item.title, categories)
                val categorizedItem = item.copy(category = detectedCategory)
                capturedItems.add(categorizedItem)
                onArticle(categorizedItem)
            }
        )

        return result.copy(items = capturedItems)
    }

    // ── Gedeeld: query → zoek (Tavily) ────────────────────────────────────────

    private fun fetchAndSummarize(
        subject: String,
        extraInstructions: String,
        preferredCount: Int,
        maxCount: Int,
        categoryId: String,
        websites: List<String> = emptyList(),
        feedback: FeedbackContext,
        searchDays: Int = 2,
        onArticle: (NewsItem) -> Unit
    ): FetchAndSummarizeResult {
        // Stap 1: Claude genereert een gerichte Engelse zoekquery
        log.info("Zoekquery genereren voor '{}'", subject)
        val query = anthropicService.generateSearchQuery(
            categoryName = subject,
            extraInstructions = extraInstructions,
            likedTitles = feedback.likedTitles,
            dislikedTitles = feedback.dislikedTitles
        )

        // Stap 2: Per bron een aparte Tavily-call
        val searchResults: List<TavilySearchResult>
        if (websites.isNotEmpty()) {
            val seenUrls = mutableSetOf<String>()
            val merged = mutableListOf<TavilySearchResult>()
            websites.forEach { site ->
                val siteResults = tavilyService.search(
                    query = query,
                    maxResults = SEARCH_POOL_SIZE,
                    days = searchDays,
                    includeDomains = listOf(site)
                )
                var added = 0
                siteResults.forEach { r ->
                    if (seenUrls.add(r.url)) { merged.add(r); added++ }
                }
                log.info("  Bron '{}': {} resultaten", site, added)
            }
            log.info("Tavily totaal voor '{}': {} unieke resultaten van {} bronnen",
                subject, merged.size, websites.size)
            if (merged.isEmpty()) return FetchAndSummarizeResult(emptyList(), 0.0, 0, 0)
            return selectExtractAndSummarize(merged, subject, extraInstructions,
                preferredCount, maxCount, categoryId, feedback, searchDays, onArticle)
        } else {
            val results = tavilyService.search(query = query, maxResults = SEARCH_POOL_SIZE, days = searchDays)
            if (results.isEmpty()) {
                log.warn("Geen zoekresultaten voor '{}'", subject)
                return FetchAndSummarizeResult(emptyList(), 0.0, 0, 0)
            }
            return selectExtractAndSummarize(results, subject, extraInstructions,
                preferredCount, maxCount, categoryId, feedback, searchDays, onArticle)
        }
    }

    // ── Gedeeld: datum-filter → selecteer → extract → vat samen ──────────────

    private fun selectExtractAndSummarize(
        searchResults: List<TavilySearchResult>,
        subject: String,
        extraInstructions: String,
        preferredCount: Int,
        maxCount: Int,
        categoryId: String,
        feedback: FeedbackContext,
        searchDays: Int,
        onArticle: (NewsItem) -> Unit
    ): FetchAndSummarizeResult {
        var totalCost = 0.0
        val searchResultCount = searchResults.size

        // Harde datum-filter
        val filtered = filterByDate(searchResults, searchDays)
        val filteredCount = filtered.size
        if (filteredCount < searchResultCount) {
            log.info("Datum-filter: {}/{} artikelen bewaard voor '{}' (max {} dagen oud)",
                filteredCount, searchResultCount, subject, searchDays)
        }
        if (filtered.isEmpty()) {
            log.warn("Geen artikelen over na datum-filter voor '{}'", subject)
            return FetchAndSummarizeResult(emptyList(), 0.0, searchResultCount, 0)
        }

        // Claude selecteert de meest relevante artikelen
        val (selectedIndices, selectionCost) = anthropicService.selectArticles(
            articles = filtered,
            categoryName = subject,
            extraInstructions = extraInstructions,
            preferredCount = preferredCount,
            maxCount = maxCount,
            likedTitles = feedback.likedTitles,
            dislikedTitles = feedback.dislikedTitles,
            topicHistoryContext = feedback.topicHistoryContext
        )
        totalCost += selectionCost

        if (selectedIndices.isEmpty()) {
            log.warn("Geen artikelen geselecteerd voor '{}'", subject)
            return FetchAndSummarizeResult(emptyList(), totalCost, searchResultCount, filteredCount)
        }

        // Tavily haalt volledige tekst op voor geselecteerde URLs
        val selectedResults = selectedIndices.map { filtered[it] }
        val extractedContent = tavilyService.extractContent(selectedResults.map { it.url })

        val publishedDateByUrl = selectedResults.associate { result ->
            result.url to (result.publishedDate ?: extractDateFromUrl(result.url))
        }.filterValues { it != null }.mapValues { it.value!! }

        // Gebruik volledige tekst indien beschikbaar, anders snippet (RSS of Tavily)
        val articles = selectedResults.map { result ->
            TavilyArticle(
                title   = result.title,
                url     = result.url,
                source  = result.source,
                content = extractedContent[result.url]?.takeIf { it.length > 200 } ?: result.snippet
            )
        }

        // Claude maakt een Nederlandse samenvatting per artikel
        val now = Instant.now().toString()
        val newsItems = mutableListOf<NewsItem>()

        articles.forEach { article ->
            log.info("Samenvatting voor '{}' ({})", article.title.take(40), subject)
            val (summarized, cost) = anthropicService.summarizeArticle(article, subject)
            val item = summarized.toNewsItem(categoryId, now, publishedDateByUrl[article.url])
            onArticle(item)
            newsItems.add(item)
            totalCost += cost
        }

        return FetchAndSummarizeResult(newsItems, totalCost, searchResultCount, filteredCount)
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
        publishedDate = publishedDate
    )
}
