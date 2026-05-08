package com.vdzon.newsfeedbackend.controller

import com.vdzon.newsfeedbackend.api.PodcastsApi
import com.vdzon.newsfeedbackend.model.CreatePodcastDto
import com.vdzon.newsfeedbackend.model.Podcast
import com.vdzon.newsfeedbackend.service.PodcastService
import org.springframework.core.io.FileSystemResource
import org.springframework.core.io.Resource
import org.springframework.http.HttpStatus
import org.springframework.http.MediaType
import org.springframework.http.ResponseEntity
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.web.bind.annotation.RestController

@RestController
class PodcastController(private val podcastService: PodcastService) : PodcastsApi {

    private val username get() = SecurityContextHolder.getContext().authentication!!.name

    override fun getPodcasts(): ResponseEntity<List<Podcast>> =
        ResponseEntity.ok(podcastService.getAll(username))

    override fun createPodcast(createPodcastDto: CreatePodcastDto): ResponseEntity<Podcast> =
        ResponseEntity.status(HttpStatus.CREATED).body(
            podcastService.create(
                username,
                createPodcastDto.periodDays,
                createPodcastDto.durationMinutes,
                createPodcastDto.customTopics,
                createPodcastDto.ttsProvider
            )
        )

    override fun getPodcast(id: String): ResponseEntity<Podcast> {
        val podcast = podcastService.getById(username, id) ?: return ResponseEntity.notFound().build()
        return ResponseEntity.ok(podcast)
    }

    override fun getPodcastAudio(id: String, token: String?, v: Int?): ResponseEntity<Resource> {
        val file = podcastService.getAudioFile(username, id)
            ?: return ResponseEntity.notFound().build()
        return ResponseEntity.ok()
            .contentType(MediaType.parseMediaType("audio/mpeg"))
            .contentLength(file.length())
            .header("Accept-Ranges", "bytes")
            .header("Cache-Control", "no-store")
            .body(FileSystemResource(file))
    }

    override fun deletePodcast(id: String): ResponseEntity<Unit> {
        podcastService.delete(username, id)
        return ResponseEntity.noContent().build()
    }
}
