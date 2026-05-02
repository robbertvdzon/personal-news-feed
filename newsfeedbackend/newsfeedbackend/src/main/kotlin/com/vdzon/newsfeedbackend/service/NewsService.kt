package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.NewsItem
import org.springframework.boot.context.event.ApplicationReadyEvent
import org.springframework.context.event.EventListener
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Service

@Service
class NewsService(
    private val storageService: StorageService,
    private val mockNewsService: MockNewsService
) {
    @EventListener(ApplicationReadyEvent::class)
    fun onStartup() {
        if (storageService.loadNews().isEmpty()) {
            refresh()
        }
    }

    @Scheduled(cron = "0 0 6 * * *")
    fun scheduledRefresh() {
        refresh()
    }

    fun refresh() {
        val newItems = mockNewsService.fetchDailyNews()
        storageService.saveNews(newItems)
    }

    fun getAll(): List<NewsItem> = storageService.loadNews()

    fun addItems(items: List<NewsItem>) {
        val current = storageService.loadNews().toMutableList()
        current.addAll(0, items)
        storageService.saveNews(current)
    }
}
