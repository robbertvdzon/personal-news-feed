package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.CategorySettings
import com.vdzon.newsfeedbackend.model.NewsItem
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import java.time.Instant
import java.util.UUID

@Service
class RealNewsSourceService(
    private val rssFeedService: RssFeedService,
    private val anthropicService: AnthropicService
) {
    private val log = LoggerFactory.getLogger(RealNewsSourceService::class.java)

    fun fetchDailyNews(categories: List<CategorySettings>): List<NewsItem> {
        val now = Instant.now().toString()
        return categories
            .filter { it.enabled }
            .flatMap { cat ->
                log.info("RSS ophalen voor categorie: {}", cat.name)
                val articles = rssFeedService.fetchForCategory(cat.id)
                if (articles.isEmpty()) {
                    log.warn("Geen RSS artikelen gevonden voor: {}", cat.name)
                    return@flatMap emptyList()
                }
                log.info("{} RSS artikelen gevonden voor {}, Claude samenvatting...", articles.size, cat.name)
                val summarized = anthropicService.summarizeForCategory(
                    articles = articles,
                    category = cat.id,
                    categoryName = cat.name,
                    count = 5,
                    extraInstructions = cat.extraInstructions
                )
                summarized.map { it.toNewsItem(cat.id, now) }
            }
    }

    fun fetchArticlesForSubject(
        subject: String,
        preferredCount: Int,
        categories: List<CategorySettings>
    ): List<NewsItem> {
        val now = Instant.now().toString()
        log.info("RSS ophalen voor onderwerp: {}", subject)
        val articles = rssFeedService.fetchAll()
        if (articles.isEmpty()) {
            log.warn("Geen RSS artikelen beschikbaar voor onderwerp: {}", subject)
            return emptyList()
        }
        log.info("{} RSS artikelen beschikbaar, Claude zoekt relevante voor: {}", articles.size, subject)
        val summarized = anthropicService.summarizeForSubject(
            articles = articles,
            subject = subject,
            count = preferredCount
        )
        // Categorie bepalen op basis van welke categorie de meeste overlap heeft
        val categoryId = detectCategory(subject, categories)
        return summarized.map { it.toNewsItem(categoryId, now) }
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
