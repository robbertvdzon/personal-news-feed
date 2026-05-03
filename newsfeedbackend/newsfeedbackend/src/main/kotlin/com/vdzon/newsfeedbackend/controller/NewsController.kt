package com.vdzon.newsfeedbackend.controller

import com.vdzon.newsfeedbackend.model.NewsItem
import com.vdzon.newsfeedbackend.service.NewsService
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
@RequestMapping("/api/news")
class NewsController(private val newsService: NewsService) {

    @GetMapping
    fun getAll(auth: Authentication): List<NewsItem> = newsService.getAll(auth.name)

    @PostMapping("/refresh")
    fun refresh(auth: Authentication): Map<String, String> {
        newsService.refresh(auth.name)
        return mapOf("status" to "ok")
    }

    @PutMapping("/{id}/read")
    fun markRead(@PathVariable id: String, auth: Authentication): Map<String, String> {
        newsService.markRead(auth.name, id)
        return mapOf("status" to "ok")
    }

    @PutMapping("/{id}/star")
    fun toggleStar(@PathVariable id: String, auth: Authentication): Map<String, String> {
        newsService.toggleStar(auth.name, id)
        return mapOf("status" to "ok")
    }

    @DeleteMapping("/cleanup")
    fun cleanup(
        @RequestParam olderThanDays: Int,
        @RequestParam(defaultValue = "true") keepStarred: Boolean,
        @RequestParam(defaultValue = "true") keepLiked: Boolean,
        auth: Authentication
    ): Map<String, Int> {
        val removed = newsService.cleanup(auth.name, olderThanDays, keepStarred, keepLiked)
        return mapOf("removed" to removed)
    }

    @PutMapping("/{id}/feedback")
    fun setFeedback(
        @PathVariable id: String,
        @RequestBody body: Map<String, Any?>,
        auth: Authentication
    ): Map<String, String> {
        val liked = body["liked"] as? Boolean
        newsService.setFeedback(auth.name, id, liked)
        return mapOf("status" to "ok")
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    fun deleteItem(@PathVariable id: String, auth: Authentication) =
        newsService.deleteItem(auth.name, id)
}
