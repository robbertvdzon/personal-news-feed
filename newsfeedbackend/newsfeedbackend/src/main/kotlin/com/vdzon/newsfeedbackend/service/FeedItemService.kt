package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.FeedItem
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import java.time.Instant

@Service
class FeedItemService(
    private val storageService: StorageService,
    private val topicHistoryService: TopicHistoryService
) {
    private val log = LoggerFactory.getLogger(FeedItemService::class.java)

    fun getAll(username: String): List<FeedItem> = storageService.loadFeedItems(username)

    fun addItem(username: String, item: FeedItem) {
        val current = storageService.loadFeedItems(username).toMutableList()
        val existingIds = current.map { it.id }.toSet()
        if (item.id in existingIds) {
            log.info("FeedItem met id '{}' bestaat al voor {}, overgeslagen", item.id, username)
            return
        }
        current.add(0, item)
        storageService.saveFeedItems(username, current)
    }

    fun addItems(username: String, items: List<FeedItem>) {
        if (items.isEmpty()) return
        val current = storageService.loadFeedItems(username).toMutableList()
        val existingIds = current.map { it.id }.toSet()
        val deduped = items.filter { it.id !in existingIds }
        if (deduped.isEmpty()) {
            log.info("Alle {} FeedItem(s) bestonden al voor {}, niets toegevoegd", items.size, username)
            return
        }
        current.addAll(0, deduped)
        storageService.saveFeedItems(username, current)
        log.info("{} nieuw(e) FeedItem(s) toegevoegd voor {} ({} duplicaten overgeslagen)",
            deduped.size, username, items.size - deduped.size)
    }

    fun updateItem(username: String, item: FeedItem) {
        val items = storageService.loadFeedItems(username).toMutableList()
        val index = items.indexOfFirst { it.id == item.id }
        if (index == -1) return
        items[index] = item
        storageService.saveFeedItems(username, items)
    }

    fun deleteItem(username: String, id: String) {
        val items = storageService.loadFeedItems(username).toMutableList()
        items.removeIf { it.id == id }
        storageService.saveFeedItems(username, items)
    }

    fun markRead(username: String, id: String) {
        val items = storageService.loadFeedItems(username).toMutableList()
        val index = items.indexOfFirst { it.id == id }
        if (index == -1) return
        items[index] = items[index].copy(isRead = true)
        storageService.saveFeedItems(username, items)
    }

    fun markUnread(username: String, id: String) {
        val items = storageService.loadFeedItems(username).toMutableList()
        val index = items.indexOfFirst { it.id == id }
        if (index == -1) return
        items[index] = items[index].copy(isRead = false)
        storageService.saveFeedItems(username, items)
    }

    fun toggleStar(username: String, id: String) {
        val items = storageService.loadFeedItems(username).toMutableList()
        val index = items.indexOfFirst { it.id == id }
        if (index == -1) return
        val item = items[index]
        val nowStarred = !item.starred
        items[index] = item.copy(starred = nowStarred)
        storageService.saveFeedItems(username, items)
        topicHistoryService.onFeedItemStarred(username, item, nowStarred)
    }

    fun setFeedback(username: String, id: String, liked: Boolean?) {
        val items = storageService.loadFeedItems(username).toMutableList()
        val index = items.indexOfFirst { it.id == id }
        if (index == -1) return
        val item = items[index]
        items[index] = item.copy(liked = liked)
        storageService.saveFeedItems(username, items)
        topicHistoryService.onFeedItemFeedback(username, item, liked)
    }

    fun cleanup(
        username: String,
        olderThanDays: Int,
        keepStarred: Boolean,
        keepLiked: Boolean,
        keepUnread: Boolean
    ): Int {
        val cutoff = Instant.now().minusSeconds(olderThanDays * 24L * 3600)
        val items = storageService.loadFeedItems(username)
        val kept = items.filter { item ->
            val isOld = try {
                Instant.parse(item.createdAt).isBefore(cutoff)
            } catch (_: Exception) { false }
            if (!isOld) return@filter true
            if (keepStarred && item.starred) return@filter true
            if (keepLiked && item.liked == true) return@filter true
            if (keepUnread && !item.isRead) return@filter true
            false
        }
        val removed = items.size - kept.size
        if (removed > 0) {
            storageService.saveFeedItems(username, kept)
            log.info("Cleanup voor {}: {} FeedItems verwijderd ({} bewaard)", username, removed, kept.size)
        }
        return removed
    }
}
