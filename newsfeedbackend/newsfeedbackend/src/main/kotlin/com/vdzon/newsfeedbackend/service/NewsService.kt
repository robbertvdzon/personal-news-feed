package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.NewsItem
import org.slf4j.LoggerFactory
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Service

@Service
class NewsService(
    private val storageService: StorageService,
    private val settingsService: SettingsService,
    private val realNewsSourceService: RealNewsSourceService,
    private val mockNewsService: MockNewsService
) {
    private val log = LoggerFactory.getLogger(NewsService::class.java)

    fun getAll(username: String): List<NewsItem> {
        val items = storageService.loadNews(username)
        if (items.isEmpty()) {
            log.info("Geen nieuws voor {}, initialiseer met mock data", username)
            val initial = mockNewsService.fetchDailyNews()
            storageService.saveNews(username, initial)
            return initial
        }
        return items
    }

    fun addItems(username: String, items: List<NewsItem>) {
        val current = storageService.loadNews(username).toMutableList()
        current.addAll(0, items)
        storageService.saveNews(username, current)
        log.info("{} nieuw(e) artikel(en) toegevoegd voor {}", items.size, username)
    }

    fun markRead(username: String, id: String) {
        val items = storageService.loadNews(username).toMutableList()
        val index = items.indexOfFirst { it.id == id }
        if (index == -1) return
        items[index] = items[index].copy(isRead = true)
        storageService.saveNews(username, items)
    }

    fun refresh(username: String) {
        log.info("Nieuws verversen voor gebruiker: {}", username)
        val categories = settingsService.getSettings(username)
        try {
            val items = realNewsSourceService.fetchDailyNews(categories)
            if (items.isNotEmpty()) {
                storageService.saveNews(username, items)
                log.info("{} nieuwsartikelen opgeslagen voor {}", items.size, username)
            } else {
                log.warn("Geen artikelen via RSS/AI, gebruik mock voor {}", username)
                storageService.saveNews(username, mockNewsService.fetchDailyNews())
            }
        } catch (e: Exception) {
            log.error("Nieuws verversen mislukt voor {}: {}", username, e.message)
        }
    }

    @Scheduled(cron = "0 0 6 * * *")
    fun scheduledRefresh() {
        log.info("Dagelijkse nieuws refresh gestart")
        storageService.getAllUsernames().forEach { refresh(it) }
    }
}
