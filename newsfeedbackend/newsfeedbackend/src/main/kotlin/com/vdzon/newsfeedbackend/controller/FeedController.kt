package com.vdzon.newsfeedbackend.controller

import com.vdzon.newsfeedbackend.api.FeedItemsApi
import com.vdzon.newsfeedbackend.model.FeedItem
import com.vdzon.newsfeedbackend.model.FeedbackBody
import com.vdzon.newsfeedbackend.model.RemovedCount
import com.vdzon.newsfeedbackend.model.StatusOk
import com.vdzon.newsfeedbackend.service.FeedItemService
import org.springframework.http.ResponseEntity
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.web.bind.annotation.RestController

@RestController
class FeedController(
    private val feedItemService: FeedItemService
) : FeedItemsApi {

    private val username get() = SecurityContextHolder.getContext().authentication!!.name

    override fun getFeedItems(): ResponseEntity<List<FeedItem>> =
        ResponseEntity.ok(feedItemService.getAll(username).sortedByDescending { it.createdAt })

    override fun markFeedRead(id: String): ResponseEntity<StatusOk> {
        feedItemService.markRead(username, id)
        return ResponseEntity.ok(StatusOk())
    }

    override fun markFeedUnread(id: String): ResponseEntity<StatusOk> {
        feedItemService.markUnread(username, id)
        return ResponseEntity.ok(StatusOk())
    }

    override fun toggleFeedStar(id: String): ResponseEntity<StatusOk> {
        feedItemService.toggleStar(username, id)
        return ResponseEntity.ok(StatusOk())
    }

    override fun setFeedFeedback(id: String, feedbackBody: FeedbackBody): ResponseEntity<StatusOk> {
        feedItemService.setFeedback(username, id, feedbackBody.liked)
        return ResponseEntity.ok(StatusOk())
    }

    override fun deleteFeedItem(id: String): ResponseEntity<StatusOk> {
        feedItemService.deleteItem(username, id)
        return ResponseEntity.ok(StatusOk())
    }

    override fun cleanupFeed(
        olderThanDays: Int,
        keepStarred: Boolean,
        keepLiked: Boolean,
        keepUnread: Boolean
    ): ResponseEntity<RemovedCount> {
        val removed = feedItemService.cleanup(username, olderThanDays, keepStarred, keepLiked, keepUnread)
        return ResponseEntity.ok(RemovedCount(removed))
    }
}
