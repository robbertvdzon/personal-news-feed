package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.CategoryResult
import com.vdzon.newsfeedbackend.model.CategorySettings
import com.vdzon.newsfeedbackend.model.NewsItem
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import java.time.Instant
import java.util.UUID

data class DailyFetchResult(
    val items: List<NewsItem>,
    val categoryResults: List<CategoryResult>,
    val totalCostUsd: Double
)

data class FeedbackContext(
    val likedTitles: List<String> = emptyList(),
    val dislikedTitles: List<String> = emptyList()
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

        categories
            .filter { it.enabled && !it.isSystem && it.id !in SYSTEM_CATEGORY_IDS }
            .forEach { cat ->
                val (items, cost) = fetchAndSummarize(
                    subject = cat.name,
                    extraInstructions = cat.extraInstructions,
                    preferredCount = cat.preferredCount,
                    maxCount = cat.maxCount,
                    categoryId = cat.id,
                    feedback = feedback,
                    onArticle = onArticle
                )
                allItems.addAll(items)
                totalCost += cost
                categoryResults.add(CategoryResult(cat.id, cat.name, items.size, cost))
                log.info("Categorie '{}': {} artikelen, kosten \${}", cat.name, items.size, "%.5f".format(cost))
            }

        return DailyFetchResult(allItems, categoryResults, totalCost)
    }

    fun fetchArticlesForSubject(
        subject: String,
        preferredCount: Int,
        extraInstructions: String = "",
        categories: List<CategorySettings>,
        feedback: FeedbackContext = FeedbackContext(),
        onArticle: (NewsItem) -> Unit = {}
    ): Pair<List<NewsItem>, Double> {
        val categoryId = detectCategory(subject, categories)
        val (items, cost) = fetchAndSummarize(
            subject = subject,
            extraInstructions = extraInstructions,
            preferredCount = preferredCount,
            maxCount = preferredCount,
            categoryId = categoryId,
            feedback = feedback,
            onArticle = onArticle
        )
        log.info("Onderwerp '{}': {} artikelen, kosten \${}", subject, items.size, "%.5f".format(cost))
        return Pair(items, cost)
    }

    // ── Gedeeld pipeline: query → zoek → selecteer → extract → samenvatten ────

    private fun fetchAndSummarize(
        subject: String,
        extraInstructions: String,
        preferredCount: Int,
        maxCount: Int,
        categoryId: String,
        feedback: FeedbackContext,
        onArticle: (NewsItem) -> Unit
    ): Pair<List<NewsItem>, Double> {
        var totalCost = 0.0

        // Stap 1: Claude genereert een gerichte Engelse zoekquery (met feedback context)
        log.info("Zoekquery genereren voor '{}'", subject)
        val query = anthropicService.generateSearchQuery(
            categoryName = subject,
            extraInstructions = extraInstructions,
            likedTitles = feedback.likedTitles,
            dislikedTitles = feedback.dislikedTitles
        )

        // Stap 2: Tavily zoekt een pool van kandidaat-artikelen (alleen titels + snippets)
        val searchResults = tavilyService.search(query = query, maxResults = SEARCH_POOL_SIZE)
        if (searchResults.isEmpty()) {
            log.warn("Geen zoekresultaten voor '{}'", subject)
            return Pair(emptyList(), 0.0)
        }

        // Stap 3: Claude selecteert de meest relevante artikelen (met feedback context)
        val (selectedIndices, selectionCost) = anthropicService.selectArticles(
            articles = searchResults,
            categoryName = subject,
            extraInstructions = extraInstructions,
            preferredCount = preferredCount,
            maxCount = maxCount,
            likedTitles = feedback.likedTitles,
            dislikedTitles = feedback.dislikedTitles
        )
        totalCost += selectionCost

        if (selectedIndices.isEmpty()) {
            log.warn("Geen artikelen geselecteerd voor '{}'", subject)
            return Pair(emptyList(), totalCost)
        }

        // Stap 4: Tavily haalt de volledige tekst op voor de geselecteerde URLs
        val selectedResults = selectedIndices.map { searchResults[it] }
        val extractedContent = tavilyService.extractContent(selectedResults.map { it.url })

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
            val item = summarized.toNewsItem(categoryId, now)
            onArticle(item)
            newsItems.add(item)
            totalCost += cost
        }

        return Pair(newsItems, totalCost)
    }

    private fun detectCategory(subject: String, categories: List<CategorySettings>): String {
        val lc = subject.lowercase()
        return categories.firstOrNull { cat ->
            lc.contains(cat.id) || lc.contains(cat.name.lowercase())
        }?.id ?: "overig"
    }

    private fun SummarizedArticle.toNewsItem(category: String, timestamp: String) = NewsItem(
        id = UUID.randomUUID().toString(),
        title = title,
        summary = summary,
        url = url,
        category = category,
        timestamp = timestamp,
        source = source
    )
}
