package com.vdzon.newsfeedbackend.controller

import com.vdzon.newsfeedbackend.model.RssFeedsSettings
import com.vdzon.newsfeedbackend.service.StorageService
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/rss-feeds")
class RssFeedsController(private val storageService: StorageService) {

    @GetMapping
    fun getRssFeeds(auth: Authentication): RssFeedsSettings =
        storageService.loadRssFeeds(auth.name)

    @PutMapping
    fun saveRssFeeds(auth: Authentication, @RequestBody settings: RssFeedsSettings): RssFeedsSettings {
        storageService.saveRssFeeds(auth.name, settings)
        return settings
    }
}
