package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.Podcast
import com.vdzon.newsfeedbackend.model.PodcastStatus
import com.vdzon.newsfeedbackend.model.TtsProvider
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import java.io.File
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.UUID

@Service
class PodcastService(
    private val storageService: StorageService,
    private val podcastProcessor: PodcastProcessor
) {
    private val log = LoggerFactory.getLogger(PodcastService::class.java)

    private val dutchMonths = arrayOf(
        "januari","februari","maart","april","mei","juni",
        "juli","augustus","september","oktober","november","december"
    )

    // Initiële titel bij aanmaken — wordt bijgewerkt na script-generatie in PodcastProcessor
    private fun initialTitle(podcastNumber: Int, customTopics: List<String>, period: String): String {
        val dt = ZonedDateTime.now(ZoneId.of("Europe/Amsterdam"))
        val date = "${dt.dayOfMonth} ${dutchMonths[dt.monthValue - 1]} ${dt.year}"
        val topicSummary = if (customTopics.isNotEmpty())
            customTopics.take(2).joinToString(", ").let { if (customTopics.size > 2) "$it en meer" else it }
        else "nieuws van $period"
        return "DevTalk $podcastNumber, $date — $topicSummary"
    }

    fun getAll(username: String): List<Podcast> =
        storageService.loadPodcasts(username)
            .sortedByDescending { it.createdAt }
            .map { it.copy(scriptText = null) }

    fun getById(username: String, id: String): Podcast? =
        storageService.loadPodcasts(username).firstOrNull { it.id == id }

    fun create(
        username: String,
        periodDays: Int,
        durationMinutes: Int,
        customTopics: List<String> = emptyList(),
        ttsProvider: TtsProvider = TtsProvider.OPENAI
    ): Podcast {
        val id = UUID.randomUUID().toString()
        val existing = storageService.loadPodcasts(username)
        val podcastNumber = (existing.maxOfOrNull { it.podcastNumber } ?: 0) + 1
        val period = when (periodDays) {
            1 -> "vandaag"
            7 -> "afgelopen week"
            14 -> "afgelopen 2 weken"
            else -> "afgelopen $periodDays dagen"
        }
        // Initiële titel — wordt bijgewerkt zodra de onderwerpen bekend zijn
        val title = initialTitle(podcastNumber, customTopics, period)

        val podcast = Podcast(
            id = id,
            title = title,
            periodDescription = period,
            periodDays = periodDays,
            durationMinutes = durationMinutes,
            status = PodcastStatus.PENDING,
            createdAt = Instant.now().toString(),
            customTopics = customTopics,
            ttsProvider = ttsProvider,
            podcastNumber = podcastNumber
        )
        val podcasts = existing.toMutableList()
        podcasts.add(0, podcast)
        storageService.savePodcasts(username, podcasts)
        log.info("Podcast #{} aangemaakt voor {}: {}d/{}min provider={}", podcastNumber, username, periodDays, durationMinutes, ttsProvider)
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
