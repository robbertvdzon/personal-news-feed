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

private val SYSTEM_CATEGORY_IDS = setOf("overig")

@Service
class RealNewsSourceService(
    private val tavilyService: TavilyService,
    private val anthropicService: AnthropicService
) {
    private val log = LoggerFactory.getLogger(RealNewsSourceService::class.java)

    fun fetchDailyNews(
        categories: List<CategorySettings>,
        onArticle: (NewsItem) -> Unit = {}
    ): DailyFetchResult {
        val allItems = mutableListOf<NewsItem>()
        val categoryResults = mutableListOf<CategoryResult>()
        var totalCost = 0.0

        categories
            .filter { it.enabled && !it.isSystem && it.id !in SYSTEM_CATEGORY_IDS }
            .forEach { cat ->
                log.info("Zoekquery genereren voor categorie '{}'", cat.name)
                val query = anthropicService.generateSearchQuery(cat.name, cat.extraInstructions)
                val articles = tavilyService.search(
                    query = query,
                    maxResults = cat.preferredCount
                )

                if (articles.isEmpty()) {
                    log.warn("Geen artikelen gevonden voor categorie '{}'", cat.name)
                    categoryResults.add(CategoryResult(cat.id, cat.name, 0, 0.0))
                    return@forEach
                }

                val now = Instant.now().toString()
                var summaryCost = 0.0
                val items = mutableListOf<NewsItem>()

                articles.forEach { article ->
                    log.info("Samenvatting voor '{}' ({})", article.title.take(40), cat.name)
                    val (summarized, cost) = anthropicService.summarizeArticle(article, cat.name)
                    val item = summarized.toNewsItem(cat.id, now)
                    onArticle(item)
                    items.add(item)
                    summaryCost += cost
                }

                allItems.addAll(items)
                totalCost += summaryCost
                categoryResults.add(CategoryResult(cat.id, cat.name, items.size, summaryCost))
                log.info("Categorie '{}': {} artikelen, kosten \${}", cat.name, items.size, "%.5f".format(summaryCost))
            }

        return DailyFetchResult(allItems, categoryResults, totalCost)
    }

    fun fetchArticlesForSubject(
        subject: String,
        preferredCount: Int,
        extraInstructions: String = "",
        categories: List<CategorySettings>,
        onArticle: (NewsItem) -> Unit = {}
    ): Pair<List<NewsItem>, Double> {
        log.info("Zoekquery genereren voor onderwerp '{}'", subject)
        val query = anthropicService.generateSearchQuery(subject, extraInstructions)
        val articles = tavilyService.search(query = query, maxResults = preferredCount)

        if (articles.isEmpty()) {
            log.warn("Geen artikelen gevonden voor onderwerp '{}'", subject)
            return Pair(emptyList(), 0.0)
        }

        val now = Instant.now().toString()
        val categoryId = detectCategory(subject, categories)
        var totalCost = 0.0
        val allItems = mutableListOf<NewsItem>()

        articles.forEach { article ->
            log.info("Samenvatting voor '{}'", article.title.take(40))
            val (summarized, cost) = anthropicService.summarizeArticle(article, subject)
            val item = summarized.toNewsItem(categoryId, now)
            onArticle(item)
            allItems.add(item)
            totalCost += cost
        }

        log.info("Onderwerp '{}': {} artikelen, kosten \${}", subject, allItems.size, "%.5f".format(totalCost))
        return Pair(allItems, totalCost)
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
