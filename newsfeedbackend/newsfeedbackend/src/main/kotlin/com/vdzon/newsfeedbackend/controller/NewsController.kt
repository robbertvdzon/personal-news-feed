package com.vdzon.newsfeedbackend.controller

import com.vdzon.newsfeedbackend.model.NewsItem
import com.vdzon.newsfeedbackend.service.NewsService
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/news")
class NewsController(private val newsService: NewsService) {

    @GetMapping
    fun getAll(): List<NewsItem> = newsService.getAll()

    @PostMapping("/refresh")
    fun refresh(): Map<String, String> {
        newsService.refresh()
        return mapOf("status" to "ok")
    }
}
