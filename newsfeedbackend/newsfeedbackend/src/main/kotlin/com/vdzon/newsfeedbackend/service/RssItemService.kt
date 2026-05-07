package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.RssItem
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import java.time.Instant

@Service
class RssItemService(
    private val storageService: StorageService,
    private val topicHistoryService: TopicHistoryService
) {
    private val log = LoggerFactory.getLogger(RssItemService::class.java)

    fun getAll(username: String): List<RssItem> = storageService.loadRssItems(username)

    fun getFeedItems(username: String): List<RssItem> =
        storageService.loadRssItems(username).filter { it.inFeed }

    fun getLikedItems(username: String): List<RssItem> =
        storageService.loadRssItems(username).filter { it.liked == true }

    fun getDislikedItems(username: String): List<RssItem> =
        storageService.loadRssItems(username).filter { it.liked == false }

    fun getStarredItems(username: String): List<RssItem> =
        storageService.loadRssItems(username).filter { it.starred }

    fun addItems(username: String, items: List<RssItem>) {
        if (items.isEmpty()) return
        val current = storageService.loadRssItems(username).toMutableList()
        val existingUrls = current.map { it.url }.toSet()
        val deduped = items.filter { it.url !in existingUrls }
        if (deduped.isEmpty()) {
            log.info("Alle {} RSS-item(s) bestonden al voor {}, niets toegevoegd", items.size, username)
            return
        }
        current.addAll(0, deduped)
        storageService.saveRssItems(username, current)
        log.info("{} nieuw(e) RSS-item(s) toegevoegd voor {} ({} duplicaten overgeslagen)",
            deduped.size, username, items.size - deduped.size)
    }

    fun updateItems(username: String, updates: List<RssItem>) {
        if (updates.isEmpty()) return
        val current = storageService.loadRssItems(username).toMutableList()
        val byId = updates.associateBy { it.id }
        val updated = current.map { byId[it.id] ?: it }
        storageService.saveRssItems(username, updated)
    }

    fun deleteItem(username: String, id: String) {
        val items = storageService.loadRssItems(username).toMutableList()
        items.removeIf { it.id == id }
        storageService.saveRssItems(username, items)
    }

    fun markRead(username: String, id: String) {
        val items = storageService.loadRssItems(username).toMutableList()
        val index = items.indexOfFirst { it.id == id }
        if (index == -1) return
        items[index] = items[index].copy(isRead = true)
        storageService.saveRssItems(username, items)
    }

    fun markUnread(username: String, id: String) {
        val items = storageService.loadRssItems(username).toMutableList()
        val index = items.indexOfFirst { it.id == id }
        if (index == -1) return
        items[index] = items[index].copy(isRead = false)
        storageService.saveRssItems(username, items)
    }

    fun toggleStar(username: String, id: String) {
        val items = storageService.loadRssItems(username).toMutableList()
        val index = items.indexOfFirst { it.id == id }
        if (index == -1) return
        val item = items[index]
        val nowStarred = !item.starred
        items[index] = item.copy(starred = nowStarred)
        storageService.saveRssItems(username, items)
        topicHistoryService.onRssItemStarred(username, item, nowStarred)
    }

    fun setFeedback(username: String, id: String, liked: Boolean?) {
        val items = storageService.loadRssItems(username).toMutableList()
        val index = items.indexOfFirst { it.id == id }
        if (index == -1) return
        val item = items[index]
        items[index] = item.copy(liked = liked)
        storageService.saveRssItems(username, items)
        topicHistoryService.onRssItemFeedback(username, item, liked)
    }

    fun cleanup(
        username: String,
        olderThanDays: Int,
        keepStarred: Boolean,
        keepLiked: Boolean,
        keepUnread: Boolean
    ): Int {
        val cutoff = Instant.now().minusSeconds(olderThanDays * 24L * 3600)
        val items = storageService.loadRssItems(username)
        val kept = items.filter { item ->
            val isOld = try {
                Instant.parse(item.timestamp).isBefore(cutoff)
            } catch (_: Exception) { false }
            if (!isOld) return@filter true
            if (keepStarred && item.starred) return@filter true
            if (keepLiked && item.liked == true) return@filter true
            if (keepUnread && !item.isRead) return@filter true
            false
        }
        val removed = items.size - kept.size
        if (removed > 0) {
            storageService.saveRssItems(username, kept)
            log.info("Cleanup voor {}: {} items verwijderd ({} bewaard)", username, removed, kept.size)
        }
        return removed
    }
}
