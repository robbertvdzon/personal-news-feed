package com.vdzon.newsfeedbackend.controller

import com.vdzon.newsfeedbackend.model.NewsItem
import com.vdzon.newsfeedbackend.service.NewsService
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestMapping
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
}
