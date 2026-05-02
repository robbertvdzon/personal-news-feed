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

@Service
class RealNewsSourceService(
    private val anthropicService: AnthropicService
) {
    private val log = LoggerFactory.getLogger(RealNewsSourceService::class.java)

    fun fetchDailyNews(categories: List<CategorySettings>): DailyFetchResult {
        val now = Instant.now().toString()
        val allItems = mutableListOf<NewsItem>()
        val categoryResults = mutableListOf<CategoryResult>()
        var totalCost = 0.0

        categories.filter { it.enabled }.forEach { cat ->
            log.info("Web search voor categorie: {}", cat.name)
            val result = anthropicService.searchAndSummarizeForCategory(cat, count = 5)
            val items = result.articles.map { it.toNewsItem(cat.id, now) }
            allItems.addAll(items)
            totalCost += result.costUsd
            categoryResults.add(
                CategoryResult(
                    categoryId = cat.id,
                    categoryName = cat.name,
                    articleCount = items.size,
                    costUsd = result.costUsd
                )
            )
            log.info("Categorie '{}': {} artikelen, kosten \${}", cat.name, items.size, "%.4f".format(result.costUsd))
        }

        return DailyFetchResult(allItems, categoryResults, totalCost)
    }

    fun fetchArticlesForSubject(
        subject: String,
        preferredCount: Int,
        extraInstructions: String = "",
        categories: List<CategorySettings>
    ): Pair<List<NewsItem>, Double> {
        val now = Instant.now().toString()
        log.info("Web search voor onderwerp: {}", subject)
        val result = anthropicService.searchAndSummarizeForSubject(
            subject = subject,
            count = preferredCount,
            extraInstructions = extraInstructions
        )
        val categoryId = detectCategory(subject, categories)
        val items = result.articles.map { it.toNewsItem(categoryId, now) }
        log.info("Onderwerp '{}': {} artikelen, kosten \${}", subject, items.size, "%.4f".format(result.costUsd))
        return Pair(items, result.costUsd)
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
