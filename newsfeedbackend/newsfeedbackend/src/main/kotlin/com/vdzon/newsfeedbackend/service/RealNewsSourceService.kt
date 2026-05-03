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

// Categorie-IDs die nooit actief gezocht worden (catch-all)
private val SYSTEM_CATEGORY_IDS = setOf("overig")

@Service
class RealNewsSourceService(
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
                log.info("Fase 1: artikelen zoeken voor categorie '{}'", cat.name)
                val (refs, searchCost) = anthropicService.findArticlesForCategory(cat, count = cat.preferredCount)
                totalCost += searchCost

                if (refs.isEmpty()) {
                    log.warn("Geen artikelen gevonden voor categorie '{}'", cat.name)
                    categoryResults.add(CategoryResult(cat.id, cat.name, 0, searchCost))
                    return@forEach
                }

                // Fase 2: sequentieel — voorkomt rate limit problemen
                val now = Instant.now().toString()
                var summaryCost = 0.0
                val items = mutableListOf<NewsItem>()

                refs.forEach { ref ->
                    log.info("Fase 2: samenvatting voor '{}' ({})", ref.title.take(40), cat.name)
                    val (article, cost) = anthropicService.summarizeArticle(ref, cat.name)
                    val item = article.toNewsItem(cat.id, now)
                    onArticle(item)
                    items.add(item)
                    summaryCost += cost
                }

                allItems.addAll(items)
                totalCost += summaryCost
                categoryResults.add(CategoryResult(cat.id, cat.name, items.size, searchCost + summaryCost))
                log.info("Categorie '{}': {} artikelen, kosten \${}", cat.name, items.size, "%.4f".format(searchCost + summaryCost))
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
        log.info("Fase 1: artikelen zoeken voor onderwerp '{}'", subject)
        val (refs, searchCost) = anthropicService.findArticles(subject, preferredCount, extraInstructions)

        if (refs.isEmpty()) {
            log.warn("Geen artikelen gevonden voor onderwerp '{}'", subject)
            return Pair(emptyList(), searchCost)
        }

        // Fase 2: sequentieel
        val now = Instant.now().toString()
        val categoryId = detectCategory(subject, categories)
        var summaryCost = 0.0
        val allItems = mutableListOf<NewsItem>()

        refs.forEach { ref ->
            log.info("Fase 2: samenvatting voor '{}'", ref.title.take(40))
            val (article, cost) = anthropicService.summarizeArticle(ref, subject)
            val item = article.toNewsItem(categoryId, now)
            onArticle(item)
            allItems.add(item)
            summaryCost += cost
        }

        val totalCost = searchCost + summaryCost
        log.info("Onderwerp '{}': {} artikelen, kosten \${}", subject, allItems.size, "%.4f".format(totalCost))
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
