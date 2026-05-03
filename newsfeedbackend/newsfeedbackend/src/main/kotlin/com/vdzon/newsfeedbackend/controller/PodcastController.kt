package com.vdzon.newsfeedbackend.controller

import com.vdzon.newsfeedbackend.model.Podcast
import com.vdzon.newsfeedbackend.service.PodcastService
import org.springframework.core.io.FileSystemResource
import org.springframework.core.io.Resource
import org.springframework.http.HttpStatus
import org.springframework.http.MediaType
import org.springframework.http.ResponseEntity
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.ResponseStatus
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/podcasts")
class PodcastController(private val podcastService: PodcastService) {

    @GetMapping
    fun getAll(auth: Authentication): List<Podcast> = podcastService.getAll(auth.name)

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    fun create(
        @RequestBody body: Map<String, Int>,
        auth: Authentication
    ): Podcast {
        val periodDays = body["periodDays"] ?: 7
        val durationMinutes = body["durationMinutes"] ?: 10
        return podcastService.create(auth.name, periodDays, durationMinutes)
    }

    @GetMapping("/{id}/audio")
    fun getAudio(@PathVariable id: String, auth: Authentication): ResponseEntity<Resource> {
        val file = podcastService.getAudioFile(auth.name, id)
            ?: return ResponseEntity.notFound().build()
        return ResponseEntity.ok()
            .contentType(MediaType.parseMediaType("audio/mpeg"))
            .contentLength(file.length())
            .body(FileSystemResource(file))
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    fun delete(@PathVariable id: String, auth: Authentication) =
        podcastService.delete(auth.name, id)
}
