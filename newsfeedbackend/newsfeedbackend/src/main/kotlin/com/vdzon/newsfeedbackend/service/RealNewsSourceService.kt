package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.CategoryResult
import com.vdzon.newsfeedbackend.model.CategorySettings
import com.vdzon.newsfeedbackend.model.NewsItem
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import java.time.Instant
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.Future

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
    private val executor = Executors.newCachedThreadPool()

    // Haalt per categorie artikelen op en roept onArticle aan zodra elk artikel klaar is
    fun fetchDailyNews(
        categories: List<CategorySettings>,
        onArticle: (NewsItem) -> Unit = {}
    ): DailyFetchResult {
        val allItems = mutableListOf<NewsItem>()
        val categoryResults = mutableListOf<CategoryResult>()
        var totalCost = 0.0

        categories.filter { it.enabled && !it.isSystem }.forEach { cat ->
            log.info("Fase 1: artikelen zoeken voor categorie '{}'", cat.name)
            val (refs, searchCost) = anthropicService.findArticlesForCategory(cat, count = cat.preferredCount)
            totalCost += searchCost

            if (refs.isEmpty()) {
                log.warn("Geen artikelen gevonden voor categorie '{}'", cat.name)
                categoryResults.add(CategoryResult(cat.id, cat.name, 0, searchCost))
                return@forEach
            }

            // Fase 2: samenvattingen parallel
            val now = Instant.now().toString()
            var summaryCost = 0.0
            val futures: List<Future<Pair<NewsItem, Double>>> = refs.map { ref ->
                executor.submit<Pair<NewsItem, Double>> {
                    log.info("Fase 2: samenvatting voor '{}' ({})", ref.title.take(40), cat.name)
                    val (article, cost) = anthropicService.summarizeArticle(ref, cat.name)
                    val item = article.toNewsItem(cat.id, now)
                    onArticle(item)
                    Pair(item, cost)
                }
            }

            futures.forEach { future ->
                val (item, cost) = future.get()
                allItems.add(item)
                summaryCost += cost
            }

            totalCost += summaryCost
            categoryResults.add(CategoryResult(cat.id, cat.name, refs.size, searchCost + summaryCost))
            log.info("Categorie '{}': {} artikelen, kosten \${}", cat.name, refs.size, "%.4f".format(searchCost + summaryCost))
        }

        return DailyFetchResult(allItems, categoryResults, totalCost)
    }

    // Haalt artikelen op voor een specifiek onderwerp en roept onArticle aan zodra elk artikel klaar is
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

        // Fase 2: samenvattingen parallel
        val now = Instant.now().toString()
        val categoryId = detectCategory(subject, categories)
        var summaryCost = 0.0

        val futures: List<Future<Pair<NewsItem, Double>>> = refs.map { ref ->
            executor.submit<Pair<NewsItem, Double>> {
                log.info("Fase 2: samenvatting voor '{}'", ref.title.take(40))
                val (article, cost) = anthropicService.summarizeArticle(ref, subject)
                val item = article.toNewsItem(categoryId, now)
                onArticle(item)
                Pair(item, cost)
            }
        }

        val allItems = futures.map { future ->
            val (item, cost) = future.get()
            summaryCost += cost
            item
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
