package com.vdzon.newsfeedbackend.controller

import com.vdzon.newsfeedbackend.model.FeedItem
import com.vdzon.newsfeedbackend.service.FeedItemService
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController

@RestController
class FeedController(
    private val feedItemService: FeedItemService
) {
    @GetMapping("/api/feed")
    fun getFeedItems(auth: Authentication): List<FeedItem> =
        feedItemService.getAll(auth.name).sortedByDescending { it.createdAt }

    @PutMapping("/api/feed/{id}/read")
    fun markRead(@PathVariable id: String, auth: Authentication): Map<String, String> {
        feedItemService.markRead(auth.name, id)
        return mapOf("status" to "ok")
    }

    @PutMapping("/api/feed/{id}/unread")
    fun markUnread(@PathVariable id: String, auth: Authentication): Map<String, String> {
        feedItemService.markUnread(auth.name, id)
        return mapOf("status" to "ok")
    }

    @PutMapping("/api/feed/{id}/star")
    fun toggleStar(@PathVariable id: String, auth: Authentication): Map<String, String> {
        feedItemService.toggleStar(auth.name, id)
        return mapOf("status" to "ok")
    }

    @PutMapping("/api/feed/{id}/feedback")
    fun setFeedback(
        @PathVariable id: String,
        @RequestBody body: Map<String, Any?>,
        auth: Authentication
    ): Map<String, String> {
        val liked = body["liked"] as? Boolean
        feedItemService.setFeedback(auth.name, id, liked)
        return mapOf("status" to "ok")
    }

    @DeleteMapping("/api/feed/{id}")
    fun deleteItem(@PathVariable id: String, auth: Authentication): Map<String, String> {
        feedItemService.deleteItem(auth.name, id)
        return mapOf("status" to "ok")
    }

    @DeleteMapping("/api/feed/cleanup")
    fun cleanup(
        @RequestParam(defaultValue = "30") olderThanDays: Int,
        @RequestParam(defaultValue = "true") keepStarred: Boolean,
        @RequestParam(defaultValue = "true") keepLiked: Boolean,
        @RequestParam(defaultValue = "false") keepUnread: Boolean,
        auth: Authentication
    ): Map<String, Int> {
        val removed = feedItemService.cleanup(auth.name, olderThanDays, keepStarred, keepLiked, keepUnread)
        return mapOf("removed" to removed)
    }
}
