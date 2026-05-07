package com.vdzon.newsfeedbackend.controller

import com.vdzon.newsfeedbackend.model.RssItem
import com.vdzon.newsfeedbackend.service.RssItemService
import com.vdzon.newsfeedbackend.service.RequestService
import org.springframework.security.core.Authentication
import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.ResponseStatus
import org.springframework.web.bind.annotation.RestController

@RestController
class NewsController(
    private val rssItemService: RssItemService,
    private val requestService: RequestService
) {

    // ── /api/news — feed-items (inFeed=true) ──────────────────────────────────

    @GetMapping("/api/news")
    fun getFeedItems(auth: Authentication): List<RssItem> =
        rssItemService.getFeedItems(auth.name)
            .sortedByDescending { it.timestamp }

    @PostMapping("/api/news/refresh")
    fun refresh(auth: Authentication): Map<String, String> {
        requestService.runDailyUpdate(auth.name)
        return mapOf("status" to "ok")
    }

    // ── /api/rss-items — alle RSS-items ───────────────────────────────────────

    @GetMapping("/api/rss-items")
    fun getAllRssItems(auth: Authentication): List<RssItem> =
        rssItemService.getAll(auth.name)
            .sortedByDescending { it.timestamp }

    // ── Gedeelde CRUD (werkt voor zowel feed als RSS-items) ───────────────────

    @PutMapping("/api/news/{id}/read")
    fun markRead(@PathVariable id: String, auth: Authentication): Map<String, String> {
        rssItemService.markRead(auth.name, id)
        return mapOf("status" to "ok")
    }

    @PutMapping("/api/news/{id}/unread")
    fun markUnread(@PathVariable id: String, auth: Authentication): Map<String, String> {
        rssItemService.markUnread(auth.name, id)
        return mapOf("status" to "ok")
    }

    @PutMapping("/api/news/{id}/star")
    fun toggleStar(@PathVariable id: String, auth: Authentication): Map<String, String> {
        rssItemService.toggleStar(auth.name, id)
        return mapOf("status" to "ok")
    }

    @PutMapping("/api/news/{id}/feedback")
    fun setFeedback(
        @PathVariable id: String,
        @RequestBody body: Map<String, Any?>,
        auth: Authentication
    ): Map<String, String> {
        val liked = body["liked"] as? Boolean
        rssItemService.setFeedback(auth.name, id, liked)
        return mapOf("status" to "ok")
    }

    @DeleteMapping("/api/news/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    fun deleteItem(@PathVariable id: String, auth: Authentication) =
        rssItemService.deleteItem(auth.name, id)

    @DeleteMapping("/api/news/cleanup")
    fun cleanup(
        @RequestParam olderThanDays: Int,
        @RequestParam(defaultValue = "true") keepStarred: Boolean,
        @RequestParam(defaultValue = "true") keepLiked: Boolean,
        @RequestParam(defaultValue = "true") keepUnread: Boolean,
        auth: Authentication
    ): Map<String, Int> {
        val removed = rssItemService.cleanup(auth.name, olderThanDays, keepStarred, keepLiked, keepUnread)
        return mapOf("removed" to removed)
    }
}
