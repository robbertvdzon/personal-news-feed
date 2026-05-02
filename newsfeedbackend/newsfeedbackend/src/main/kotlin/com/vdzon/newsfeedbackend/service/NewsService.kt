package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.NewsItem
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Service

@Service
class NewsService(
    private val storageService: StorageService,
    private val mockNewsService: MockNewsService
) {
    fun getAll(username: String): List<NewsItem> {
        val items = storageService.loadNews(username)
        if (items.isEmpty()) {
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
    }

    fun refresh(username: String) {
        val newItems = mockNewsService.fetchDailyNews()
        storageService.saveNews(username, newItems)
    }

    @Scheduled(cron = "0 0 6 * * *")
    fun scheduledRefresh() {
        storageService.getAllUsernames().forEach { refresh(it) }
    }
}
