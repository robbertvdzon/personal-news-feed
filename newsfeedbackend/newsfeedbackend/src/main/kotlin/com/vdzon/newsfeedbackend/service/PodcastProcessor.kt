package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.Podcast
import com.vdzon.newsfeedbackend.model.PodcastStatus
import org.slf4j.LoggerFactory
import org.springframework.scheduling.annotation.Async
import org.springframework.stereotype.Service
import java.io.File
import java.time.Instant

@Service
class PodcastProcessor(
    private val storageService: StorageService,
    private val newsService: NewsService,
    private val anthropicService: AnthropicService,
    private val openAITtsService: OpenAITtsService
) {
    private val log = LoggerFactory.getLogger(PodcastProcessor::class.java)

    @Async
    fun process(username: String, podcastId: String) {
        updateStatus(username, podcastId, PodcastStatus.GENERATING_SCRIPT)
        try {
            val podcast = storageService.loadPodcasts(username)
                .firstOrNull { it.id == podcastId } ?: return

            // Laad nieuws-items van de opgegeven periode
            val cutoff = Instant.now().minusSeconds(podcast.periodDays * 24L * 3600)
            val articles = newsService.getAll(username).filter { item ->
                !item.isSummary && try {
                    Instant.parse(item.timestamp).isAfter(cutoff)
                } catch (_: Exception) { false }
            }
            log.info("Podcast script genereren: {} artikelen ({} dagen) voor {}", articles.size, podcast.periodDays, username)

            // Eerder besproken onderwerpen uit bestaande podcasts
            val previousTopics = storageService.loadPodcasts(username)
                .filter { it.id != podcastId && it.scriptText != null }
                .flatMap { p ->
                    p.scriptText!!.lines()
                        .filter { it.startsWith("INTERVIEWER:") || it.startsWith("GAST:") }
                        .take(3)
                        .map { it.substringAfter(":").trim().take(80) }
                }
                .take(20)

            val (scriptText, scriptCost) = anthropicService.generatePodcastScript(
                articles = articles,
                periodDays = podcast.periodDays,
                durationMinutes = podcast.durationMinutes,
                previousTopics = previousTopics
            )

            updatePodcast(username, podcastId) {
                it.copy(scriptText = scriptText, status = PodcastStatus.GENERATING_AUDIO)
            }

            // Audio genereren (twee stemmen)
            val audioDir = storageService.audioDirForUser(username)
            val audioFile = File(audioDir, "$podcastId.mp3")
            val (durationSeconds, ttsCost) = openAITtsService.generateAudio(scriptText, audioFile)
            val totalCost = scriptCost + ttsCost

            updatePodcast(username, podcastId) {
                it.copy(
                    status = PodcastStatus.DONE,
                    audioPath = audioFile.absolutePath,
                    durationSeconds = durationSeconds,
                    costUsd = totalCost
                )
            }
            log.info("Podcast klaar voor {}: {} sec, \${}", username, durationSeconds, "%.4f".format(totalCost))

        } catch (e: Exception) {
            log.error("Podcast generatie mislukt voor {} ({}): {}", username, podcastId, e.message)
            updateStatus(username, podcastId, PodcastStatus.FAILED)
        }
    }

    private fun updateStatus(username: String, id: String, status: PodcastStatus) =
        updatePodcast(username, id) { it.copy(status = status) }

    private fun updatePodcast(username: String, id: String, update: (Podcast) -> Podcast) {
        val podcasts = storageService.loadPodcasts(username).toMutableList()
        val index = podcasts.indexOfFirst { it.id == id }
        if (index == -1) return
        podcasts[index] = update(podcasts[index])
        storageService.savePodcasts(username, podcasts)
    }
}
