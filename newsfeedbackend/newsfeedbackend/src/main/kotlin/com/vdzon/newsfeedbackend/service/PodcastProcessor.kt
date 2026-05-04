package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.Podcast
import com.vdzon.newsfeedbackend.model.PodcastStatus
import com.vdzon.newsfeedbackend.model.TtsProvider
import org.slf4j.LoggerFactory
import org.springframework.scheduling.annotation.Async
import org.springframework.stereotype.Service
import java.io.File
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime

@Service
class PodcastProcessor(
    private val storageService: StorageService,
    private val newsService: NewsService,
    private val anthropicService: AnthropicService,
    private val openAITtsService: OpenAITtsService,
    private val elevenLabsTtsService: ElevenLabsTtsService,
    private val topicHistoryService: TopicHistoryService
) {
    private val dutchMonths = arrayOf(
        "januari","februari","maart","april","mei","juni",
        "juli","augustus","september","oktober","november","december"
    )

    private fun buildTitle(
        podcastNumber: Int,
        customTopics: List<String>,
        extractedTopics: List<String>,
        period: String,
        createdAt: String
    ): String {
        val instant = try { Instant.parse(createdAt) } catch (_: Exception) { Instant.now() }
        val dt = ZonedDateTime.ofInstant(instant, ZoneId.of("Europe/Amsterdam"))
        val date = "${dt.dayOfMonth} ${dutchMonths[dt.monthValue - 1]} ${dt.year}"
        val topicSummary = when {
            customTopics.isNotEmpty() -> {
                val shown = customTopics.take(2).joinToString(", ")
                if (customTopics.size > 2) "$shown en meer" else shown
            }
            extractedTopics.isNotEmpty() -> {
                val shown = extractedTopics.take(2).joinToString(", ")
                if (extractedTopics.size > 2) "$shown en meer" else shown
            }
            else -> "nieuws van $period"
        }
        return "DevTalk $podcastNumber, $date — $topicSummary"
    }
    private val log = LoggerFactory.getLogger(PodcastProcessor::class.java)

    @Async
    fun process(username: String, podcastId: String) {
        val startInstant = Instant.now()
        updateStatus(username, podcastId, PodcastStatus.GENERATING_SCRIPT)
        try {
            val podcast = storageService.loadPodcasts(username)
                .firstOrNull { it.id == podcastId } ?: return

            // Nieuwsartikelen van de opgegeven periode
            val cutoff = Instant.now().minusSeconds(podcast.periodDays * 24L * 3600)
            val articles = newsService.getAll(username).filter { item ->
                !item.isSummary && try {
                    Instant.parse(item.timestamp).isAfter(cutoff)
                } catch (_: Exception) { false }
            }
            log.info("Podcast script genereren: {} artikelen ({} dagen) voor {}", articles.size, podcast.periodDays, username)

            // Topic-geschiedenis ophalen voor betere onderwerpkeuze
            val topicHistoryContext = topicHistoryService.buildPodcastContext(username)

            val (scriptText, scriptCost) = anthropicService.generatePodcastScript(
                articles = articles,
                periodDays = podcast.periodDays,
                durationMinutes = podcast.durationMinutes,
                topicHistoryContext = topicHistoryContext,
                customTopics = podcast.customTopics
            )

            // Onderwerpen extraheren en titel bijwerken
            val (topics, topicsCost) = anthropicService.extractPodcastTopics(scriptText)
            val updatedTitle = buildTitle(
                podcastNumber = podcast.podcastNumber,
                customTopics = podcast.customTopics,
                extractedTopics = topics,
                period = podcast.periodDescription,
                createdAt = podcast.createdAt
            )

            // Werk topic-geschiedenis bij: eerste helft = diepgaand behandeld
            val deepTopics = topics.take((topics.size + 1) / 2)
            topicHistoryService.mergePodcastTopics(username, topics, deepTopics)

            updatePodcast(username, podcastId) {
                it.copy(
                    scriptText = scriptText,
                    topics = topics,
                    title = updatedTitle,
                    status = PodcastStatus.GENERATING_AUDIO
                )
            }

            // Audio genereren via gekozen provider
            val audioDir = storageService.audioDirForUser(username)
            val audioFile = File(audioDir, "$podcastId.mp3")
            log.info("Audio genereren via {} voor {}", podcast.ttsProvider, username)
            val (durationSeconds, ttsCost) = when (podcast.ttsProvider) {
                TtsProvider.ELEVENLABS -> elevenLabsTtsService.generateAudio(scriptText, audioFile)
                else -> openAITtsService.generateAudio(scriptText, audioFile)
            }

            val totalCost = scriptCost + topicsCost + ttsCost
            val generationSeconds = (Instant.now().epochSecond - startInstant.epochSecond).toInt()

            updatePodcast(username, podcastId) {
                it.copy(
                    status = PodcastStatus.DONE,
                    audioPath = audioFile.absolutePath,
                    durationSeconds = durationSeconds,
                    costUsd = totalCost,
                    generationSeconds = generationSeconds
                )
            }
            log.info("Podcast klaar voor {}: audio={}s, generatie={}s, \${}", username, durationSeconds, generationSeconds, "%.4f".format(totalCost))

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
