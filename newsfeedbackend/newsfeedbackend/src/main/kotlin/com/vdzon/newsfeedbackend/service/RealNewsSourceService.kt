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

@Service
class RealNewsSourceService(
    private val tavilyService: TavilyService,
    private val anthropicService: AnthropicService
) {
    private val log = LoggerFactory.getLogger(RealNewsSourceService::class.java)

    fun fetchDailyNews(
        categories: List<CategorySettings>,
        feedback: FeedbackContext = FeedbackContext(),
        onArticle: (NewsItem) -> Unit = {}
    ): DailyFetchResult {
        val allItems = mutableListOf<NewsItem>()
        val categoryResults = mutableListOf<CategoryResult>()
        var totalCost = 0.0

        val enabledCategories = categories.filter { it.enabled && !it.isSystem && it.id !in SYSTEM_CATEGORY_IDS }

        enabledCategories.forEach { cat ->
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
                cat.name, result.searchResultCount, result.filteredCount, result.items.size, "%.5f".format(result.costUsd))
        }

        // Dagelijks overzicht: redactionele briefing van alle gevonden artikelen
        if (allItems.isNotEmpty()) {
            val categoryNames = enabledCategories.map { it.name }
            try {
                log.info("Dagelijks overzicht genereren op basis van {} artikelen", allItems.size)
                val (summaryItem, summaryCost) = anthropicService.generateDailySummary(allItems, categoryNames)
                allItems.add(0, summaryItem)
                onArticle(summaryItem)   // ook via streaming callback opslaan
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
        feedback: FeedbackContext = FeedbackContext(),
        onArticle: (NewsItem) -> Unit = {}
    ): Pair<List<NewsItem>, Double> {
        val categoryId = detectCategory(subject, categories)
        val categoryWebsites = categories.firstOrNull { it.id == categoryId }?.websites ?: emptyList()
        val result = fetchAndSummarize(
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
        log.info("Onderwerp '{}': {} gevonden, {} na filter, {} toegevoegd, kosten \${}",
            subject, result.searchResultCount, result.filteredCount, result.items.size, "%.5f".format(result.costUsd))
        return Pair(result.items, result.costUsd)
    }

    // ── Gedeeld pipeline: query → zoek → selecteer → extract → samenvatten ────

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
        var totalCost = 0.0

        // Stap 1: Claude genereert een gerichte Engelse zoekquery (met feedback context)
        log.info("Zoekquery genereren voor '{}'", subject)
        val query = anthropicService.generateSearchQuery(
            categoryName = subject,
            extraInstructions = extraInstructions,
            likedTitles = feedback.likedTitles,
            dislikedTitles = feedback.dislikedTitles
        )

        // Stap 2: Tavily zoekt in gecureerde websites (met fallback naar breed zoeken)
        var searchResults = if (websites.isNotEmpty()) {
            val results = tavilyService.search(query = query, maxResults = SEARCH_POOL_SIZE, days = searchDays, includeDomains = websites)
            if (results.isEmpty()) {
                log.warn("Geen resultaten binnen gecureerde websites voor '{}', terugvallen op breed zoeken", subject)
                tavilyService.search(query = query, maxResults = SEARCH_POOL_SIZE, days = searchDays)
            } else results
        } else {
            tavilyService.search(query = query, maxResults = SEARCH_POOL_SIZE, days = searchDays)
        }

        if (searchResults.isEmpty()) {
            log.warn("Geen zoekresultaten voor '{}'", subject)
            return FetchAndSummarizeResult(emptyList(), 0.0, 0, 0)
        }
        val searchResultCount = searchResults.size

        // Stap 2.5: Harde datum-filter — verwijder artikelen met een bekende datum die ouder zijn dan searchDays
        searchResults = filterByDate(searchResults, searchDays)
        val filteredCount = searchResults.size
        if (filteredCount < searchResultCount) {
            log.info("Datum-filter: {}/{} artikelen bewaard voor '{}' (max {} dagen oud)",
                filteredCount, searchResultCount, subject, searchDays)
        }
        if (searchResults.isEmpty()) {
            log.warn("Geen artikelen over na datum-filter voor '{}'", subject)
            return FetchAndSummarizeResult(emptyList(), 0.0, searchResultCount, 0)
        }

        // Stap 3: Claude selecteert de meest relevante artikelen (met feedback + topic-geschiedenis)
        val (selectedIndices, selectionCost) = anthropicService.selectArticles(
            articles = searchResults,
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

        // Stap 4: Tavily haalt de volledige tekst op voor de geselecteerde URLs
        val selectedResults = selectedIndices.map { searchResults[it] }
        val extractedContent = tavilyService.extractContent(selectedResults.map { it.url })

        // Sla publicatiedatums op per URL voor later gebruik
        // Gebruik Tavily-datum als beschikbaar, anders probeer datum uit de URL te halen
        val publishedDateByUrl = selectedResults.associate { result ->
            result.url to (result.publishedDate ?: extractDateFromUrl(result.url))
        }.filterValues { it != null }.mapValues { it.value!! }

        // Maak TavilyArticle objecten met volledige tekst (of snippet als fallback)
        val articles = selectedResults.map { result ->
            TavilyArticle(
                title = result.title,
                url = result.url,
                source = result.source,
                content = extractedContent[result.url]?.takeIf { it.length > 200 } ?: result.snippet
            )
        }

        // Stap 5: Claude maakt een Nederlandse samenvatting per artikel
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

    private fun detectCategory(subject: String, categories: List<CategorySettings>): String {
        val lc = subject.lowercase()
        return categories.firstOrNull { cat ->
            lc.contains(cat.id) || lc.contains(cat.name.lowercase())
        }?.id ?: "overig"
    }

    /**
     * Verwijdert artikelen waarvan de publicatiedatum bekend is én ouder is dan maxAgeDays.
     * Artikelen zonder datum worden altijd bewaard (we weten immers niet hoe oud ze zijn).
     * Er wordt een buffer van +1 dag gebruikt voor tijdzone-verschillen.
     */
    private fun filterByDate(results: List<TavilySearchResult>, maxAgeDays: Int): List<TavilySearchResult> {
        val cutoff = LocalDate.now().minusDays(maxAgeDays.toLong() + 1)
        return results.filter { result ->
            val pubDate = result.publishedDate ?: return@filter true // geen datum → bewaren
            try {
                val date = LocalDate.parse(pubDate.take(10)) // neem alleen YYYY-MM-DD deel
                !date.isBefore(cutoff)
            } catch (_: Exception) {
                true // onparseerbare datum → bewaren
            }
        }
    }

    /** Probeert een datum te herkennen in de URL, bijv. /2025/01/21/ of /2025-01-21 */
    private fun extractDateFromUrl(url: String): String? {
        // Patroon: /yyyy/mm/dd/ of /yyyy-mm-dd of ?date=yyyy-mm-dd
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
            // Sanity check: jaar 2010-2030, maand 1-12, dag 1-31
            if (y in 2010..2030 && m in 1..12 && d in 1..31) {
                return "$year-${month.padStart(2, '0')}-${day.padStart(2, '0')}"
            }
        }
        return null
    }

    private fun SummarizedArticle.toNewsItem(category: String, timestamp: String, publishedDate: String? = null) = NewsItem(
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
