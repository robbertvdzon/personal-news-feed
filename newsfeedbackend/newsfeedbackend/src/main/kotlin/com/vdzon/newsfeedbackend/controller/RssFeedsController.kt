package com.vdzon.newsfeedbackend.controller

import com.vdzon.newsfeedbackend.api.RSSFeedsApi
import com.vdzon.newsfeedbackend.model.RssFeedsSettings
import com.vdzon.newsfeedbackend.service.StorageService
import org.springframework.http.ResponseEntity
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.web.bind.annotation.RestController

@RestController
class RssFeedsController(private val storageService: StorageService) : RSSFeedsApi {

    private val username get() = SecurityContextHolder.getContext().authentication!!.name

    override fun getRssFeeds(): ResponseEntity<RssFeedsSettings> =
        ResponseEntity.ok(storageService.loadRssFeeds(username))

    override fun saveRssFeeds(rssFeedsSettings: RssFeedsSettings): ResponseEntity<RssFeedsSettings> {
        storageService.saveRssFeeds(username, rssFeedsSettings)
        return ResponseEntity.ok(rssFeedsSettings)
    }
}
