package com.vdzon.newsfeedbackend.controller

import com.vdzon.newsfeedbackend.model.RssItem
import com.vdzon.newsfeedbackend.service.RssItemService
import com.vdzon.newsfeedbackend.service.RequestService
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController

@RestController
class RssController(
    private val rssItemService: RssItemService,
    private val requestService: RequestService
) {

    // ── GET /api/rss — alle RSS-items ─────────────────────────────────────────

    @GetMapping("/api/rss")
    fun getAllRssItems(auth: Authentication): List<RssItem> =
        rssItemService.getAll(auth.name)
            .sortedByDescending { it.timestamp }

    // ── POST /api/rss/refresh — trigger dagelijkse update ─────────────────────

    @PostMapping("/api/rss/refresh")
    fun refresh(auth: Authentication): Map<String, String> {
        requestService.runDailyUpdate(auth.name)
        return mapOf("status" to "ok")
    }

    // ── CRUD op RssItems via /api/rss ─────────────────────────────────────────

    @PutMapping("/api/rss/{id}/read")
    fun markRead(@PathVariable id: String, auth: Authentication): Map<String, String> {
        rssItemService.markRead(auth.name, id)
        return mapOf("status" to "ok")
    }

    @PutMapping("/api/rss/{id}/unread")
    fun markUnread(@PathVariable id: String, auth: Authentication): Map<String, String> {
        rssItemService.markUnread(auth.name, id)
        return mapOf("status" to "ok")
    }

    @PutMapping("/api/rss/{id}/star")
    fun toggleStar(@PathVariable id: String, auth: Authentication): Map<String, String> {
        rssItemService.toggleStar(auth.name, id)
        return mapOf("status" to "ok")
    }

    @PutMapping("/api/rss/{id}/feedback")
    fun setFeedback(
        @PathVariable id: String,
        @RequestBody body: Map<String, Any?>,
        auth: Authentication
    ): Map<String, String> {
        val liked = body["liked"] as? Boolean
        rssItemService.setFeedback(auth.name, id, liked)
        return mapOf("status" to "ok")
    }

    @DeleteMapping("/api/rss/{id}")
    fun deleteItem(@PathVariable id: String, auth: Authentication): Map<String, String> {
        rssItemService.deleteItem(auth.name, id)
        return mapOf("status" to "ok")
    }

    @DeleteMapping("/api/rss/cleanup")
    fun cleanup(
        @RequestParam(defaultValue = "30") olderThanDays: Int,
        @RequestParam(defaultValue = "true") keepStarred: Boolean,
        @RequestParam(defaultValue = "true") keepLiked: Boolean,
        @RequestParam(defaultValue = "false") keepUnread: Boolean,
        auth: Authentication
    ): Map<String, Int> {
        val removed = rssItemService.cleanup(auth.name, olderThanDays, keepStarred, keepLiked, keepUnread)
        return mapOf("removed" to removed)
    }
}
