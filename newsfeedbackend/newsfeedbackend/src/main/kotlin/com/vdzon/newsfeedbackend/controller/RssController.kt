package com.vdzon.newsfeedbackend.controller

import com.vdzon.newsfeedbackend.api.RSSItemsApi
import com.vdzon.newsfeedbackend.model.FeedbackBody
import com.vdzon.newsfeedbackend.model.RemovedCount
import com.vdzon.newsfeedbackend.model.RssItem
import com.vdzon.newsfeedbackend.model.StatusOk
import com.vdzon.newsfeedbackend.service.RequestService
import com.vdzon.newsfeedbackend.service.RssItemService
import org.springframework.http.ResponseEntity
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.web.bind.annotation.RestController

@RestController
class RssController(
    private val rssItemService: RssItemService,
    private val requestService: RequestService
) : RSSItemsApi {

    private val username get() = SecurityContextHolder.getContext().authentication!!.name

    override fun getRssItems(): ResponseEntity<List<RssItem>> =
        ResponseEntity.ok(rssItemService.getAll(username).sortedByDescending { it.timestamp })

    override fun refreshRss(): ResponseEntity<StatusOk> {
        requestService.runDailyUpdate(username)
        return ResponseEntity.ok(StatusOk())
    }

    override fun markRssRead(id: String): ResponseEntity<StatusOk> {
        rssItemService.markRead(username, id)
        return ResponseEntity.ok(StatusOk())
    }

    override fun markRssUnread(id: String): ResponseEntity<StatusOk> {
        rssItemService.markUnread(username, id)
        return ResponseEntity.ok(StatusOk())
    }

    override fun toggleRssStar(id: String): ResponseEntity<StatusOk> {
        rssItemService.toggleStar(username, id)
        return ResponseEntity.ok(StatusOk())
    }

    override fun setRssFeedback(id: String, feedbackBody: FeedbackBody): ResponseEntity<StatusOk> {
        rssItemService.setFeedback(username, id, feedbackBody.liked)
        return ResponseEntity.ok(StatusOk())
    }

    override fun deleteRssItem(id: String): ResponseEntity<StatusOk> {
        rssItemService.deleteItem(username, id)
        return ResponseEntity.ok(StatusOk())
    }

    override fun cleanupRss(
        olderThanDays: Int,
        keepStarred: Boolean,
        keepLiked: Boolean,
        keepUnread: Boolean
    ): ResponseEntity<RemovedCount> {
        val removed = rssItemService.cleanup(username, olderThanDays, keepStarred, keepLiked, keepUnread)
        return ResponseEntity.ok(RemovedCount(removed))
    }
}
