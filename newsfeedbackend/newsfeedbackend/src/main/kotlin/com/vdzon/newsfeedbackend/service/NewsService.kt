package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.NewsItem
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service

@Service
class NewsService(
    private val storageService: StorageService,
    private val settingsService: SettingsService,
    private val realNewsSourceService: RealNewsSourceService,
    private val topicHistoryService: TopicHistoryService
) {
    private val log = LoggerFactory.getLogger(NewsService::class.java)

    fun getAll(username: String): List<NewsItem> = storageService.loadNews(username)

    fun addItems(username: String, items: List<NewsItem>) {
        val current = storageService.loadNews(username).toMutableList()
        current.addAll(0, items)
        storageService.saveNews(username, current)
        log.info("{} nieuw(e) artikel(en) toegevoegd voor {}", items.size, username)
    }

    fun deleteItem(username: String, id: String) {
        val items = storageService.loadNews(username).toMutableList()
        items.removeIf { it.id == id }
        storageService.saveNews(username, items)
    }

    fun markRead(username: String, id: String) {
        val items = storageService.loadNews(username).toMutableList()
        val index = items.indexOfFirst { it.id == id }
        if (index == -1) return
        items[index] = items[index].copy(isRead = true)
        storageService.saveNews(username, items)
    }

    fun markUnread(username: String, id: String) {
        val items = storageService.loadNews(username).toMutableList()
        val index = items.indexOfFirst { it.id == id }
        if (index == -1) return
        items[index] = items[index].copy(isRead = false)
        storageService.saveNews(username, items)
    }

    fun setFeedback(username: String, id: String, liked: Boolean?) {
        val items = storageService.loadNews(username).toMutableList()
        val index = items.indexOfFirst { it.id == id }
        if (index == -1) return
        val item = items[index]
        items[index] = item.copy(liked = liked)
        storageService.saveNews(username, items)
        // Werk topic-geschiedenis bij als de gebruiker een like geeft
        topicHistoryService.onFeedback(username, item, liked)
    }

    fun getLikedItems(username: String): List<NewsItem> =
        storageService.loadNews(username).filter { it.liked == true }

    fun getDislikedItems(username: String): List<NewsItem> =
        storageService.loadNews(username).filter { it.liked == false }

    fun getRecentItems(username: String, days: Int = 3): List<NewsItem> {
        val cutoff = java.time.Instant.now().minusSeconds(days * 24L * 3600)
        return storageService.loadNews(username).filter {
            try { java.time.Instant.parse(it.timestamp).isAfter(cutoff) } catch (_: Exception) { false }
        }
    }

    fun cleanup(username: String, olderThanDays: Int, keepStarred: Boolean, keepLiked: Boolean, keepUnread: Boolean): Int {
        val cutoff = java.time.Instant.now().minusSeconds(olderThanDays * 24L * 3600)
        val items = storageService.loadNews(username)
        val kept = items.filter { item ->
            val isOld = try {
                java.time.Instant.parse(item.timestamp).isBefore(cutoff)
            } catch (_: Exception) { false }
            if (!isOld) return@filter true          // bewaar altijd recente items
            if (keepStarred && item.starred) return@filter true
            if (keepLiked && item.liked == true) return@filter true
            if (keepUnread && !item.isRead) return@filter true
            false                                   // verwijder
        }
        val removed = items.size - kept.size
        if (removed > 0) {
            storageService.saveNews(username, kept)
            log.info("Cleanup voor {}: {} artikelen verwijderd ({} bewaard)", username, removed, kept.size)
        }
        return removed
    }

    fun toggleStar(username: String, id: String) {
        val items = storageService.loadNews(username).toMutableList()
        val index = items.indexOfFirst { it.id == id }
        if (index == -1) return
        val item = items[index]
        val nowStarred = !item.starred
        items[index] = item.copy(starred = nowStarred)
        storageService.saveNews(username, items)
        // Werk topic-geschiedenis bij
        topicHistoryService.onStarred(username, item, nowStarred)
    }

    fun refresh(username: String) {
        log.info("Nieuws verversen voor gebruiker: {}", username)
        val categories = settingsService.getSettings(username)
        val rssUrls = storageService.loadRssFeeds(username).feeds
        try {
            val feedback = FeedbackContext(
                likedTitles = getLikedItems(username).map { it.title }.take(10),
                dislikedTitles = getDislikedItems(username).map { it.title }.take(10),
                topicHistoryContext = topicHistoryService.buildNewsContext(username)
            )
            val savedItems = mutableListOf<NewsItem>()
            val fetchResult = realNewsSourceService.fetchDailyNews(
                categories = categories,
                rssUrls = rssUrls,
                feedback = feedback,
                onArticle = { item ->
                    // Direct opslaan zodat het meteen zichtbaar is in de feed
                    addItems(username, listOf(item))
                    savedItems.add(item)
                }
            )
            if (savedItems.isNotEmpty()) {
                // Topics extraheren en bestaande items in de opslag bijwerken
                val itemsWithTopics = topicHistoryService.extractAndUpdateFromNewsItems(username, savedItems)
                val topicsById = itemsWithTopics.associate { it.id to it.topics }
                val current = storageService.loadNews(username).toMutableList()
                val updated = current.map { item ->
                    val newTopics = topicsById[item.id]
                    if (!newTopics.isNullOrEmpty()) item.copy(topics = newTopics) else item
                }
                storageService.saveNews(username, updated)
                log.info("{} nieuwsartikelen opgeslagen voor {} (met topics)", savedItems.size, username)
            } else {
                log.warn("Geen nieuwe artikelen gevonden voor {}", username)
            }
        } catch (e: Exception) {
            log.error("Nieuws verversen mislukt voor {}: {}", username, e.message)
        }
    }
}
