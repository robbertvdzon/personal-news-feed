package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.Podcast
import com.vdzon.newsfeedbackend.model.PodcastStatus
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import java.io.File
import java.time.Instant
import java.util.UUID

@Service
class PodcastService(
    private val storageService: StorageService,
    private val podcastProcessor: PodcastProcessor
) {
    private val log = LoggerFactory.getLogger(PodcastService::class.java)

    fun getAll(username: String): List<Podcast> =
        storageService.loadPodcasts(username)
            .sortedByDescending { it.createdAt }
            .map { it.copy(scriptText = null) }   // script niet meesturen naar frontend

    fun create(username: String, periodDays: Int, durationMinutes: Int): Podcast {
        val id = UUID.randomUUID().toString()
        val period = when (periodDays) {
            1 -> "Vandaag"
            7 -> "Afgelopen week"
            14 -> "Afgelopen 2 weken"
            else -> "Afgelopen $periodDays dagen"
        }
        val podcast = Podcast(
            id = id,
            title = "Podcast — $period",
            periodDescription = period,
            periodDays = periodDays,
            durationMinutes = durationMinutes,
            status = PodcastStatus.PENDING,
            createdAt = Instant.now().toString()
        )
        val podcasts = storageService.loadPodcasts(username).toMutableList()
        podcasts.add(0, podcast)
        storageService.savePodcasts(username, podcasts)
        log.info("Podcast aangemaakt voor {}: {}d / {}min", username, periodDays, durationMinutes)
        podcastProcessor.process(username, id)
        return podcast
    }

    fun delete(username: String, id: String) {
        val podcasts = storageService.loadPodcasts(username).toMutableList()
        val podcast = podcasts.firstOrNull { it.id == id }
        podcast?.audioPath?.let { File(it).delete() }
        podcasts.removeIf { it.id == id }
        storageService.savePodcasts(username, podcasts)
        log.info("Podcast {} verwijderd voor {}", id, username)
    }

    fun getAudioFile(username: String, id: String): File? {
        val podcast = storageService.loadPodcasts(username).firstOrNull { it.id == id }
            ?: return null
        val path = podcast.audioPath ?: return null
        val file = File(path)
        return if (file.exists()) file else null
    }
}
