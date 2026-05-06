package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.CategoryResult
import com.vdzon.newsfeedbackend.model.NewsRequest
import com.vdzon.newsfeedbackend.model.RequestStatus
import com.vdzon.newsfeedbackend.websocket.RequestWebSocketHandler
import org.slf4j.LoggerFactory
import org.springframework.scheduling.annotation.Async
import org.springframework.stereotype.Service
import java.time.Instant

@Service
class RequestProcessor(
    private val storageService: StorageService,
    private val realNewsSourceService: RealNewsSourceService,
    private val settingsService: SettingsService,
    private val newsService: NewsService,
    private val webSocketHandler: RequestWebSocketHandler
) {
    private fun loadFeedback(username: String): FeedbackContext {
        val liked = newsService.getLikedItems(username).map { it.title }
        val disliked = newsService.getDislikedItems(username).map { it.title }
        if (liked.isNotEmpty() || disliked.isNotEmpty()) {
            log.info("Feedback context: {} geliked, {} gedisliked", liked.size, disliked.size)
        }
        return FeedbackContext(likedTitles = liked, dislikedTitles = disliked)
    }
    private val log = LoggerFactory.getLogger(RequestProcessor::class.java)

    @Async
    fun processRequest(username: String, request: NewsRequest) {
        updateStatus(username, request.id, RequestStatus.PROCESSING)
        try {
            val categories = settingsService.getSettings(username)
            val rssUrls = storageService.loadRssFeeds(username).feeds
            val feedback = loadFeedback(username)
            val (articles, costUsd) = realNewsSourceService.fetchArticlesForSubject(
                subject = request.subject,
                preferredCount = request.preferredCount,
                extraInstructions = request.extraInstructions,
                maxAgeDays = request.maxAgeDays,
                categories = categories,
                rssUrls = rssUrls,
                feedback = feedback,
                onArticle = { item ->
                    newsService.addItems(username, listOf(item))
                    log.info("Artikel direct toegevoegd: '{}'", item.title.take(50))
                }
            )
            if (articles.isNotEmpty()) {
                log.info("Verzoek '{}' afgerond voor {}: {} artikelen", request.subject, username, articles.size)
            } else {
                log.warn("Verzoek '{}' afgerond voor {}: geen artikelen gevonden", request.subject, username)
            }
            updateStatus(username, request.id, RequestStatus.DONE, articles.size, costUsd)
        } catch (e: Exception) {
            log.error("Request verwerking mislukt voor {}: {}", username, e.message)
            updateStatus(username, request.id, RequestStatus.FAILED)
        }
    }

    @Async
    fun processDailyUpdate(username: String, requestId: String) {
        updateStatus(username, requestId, RequestStatus.PROCESSING)
        try {
            val categories = settingsService.getSettings(username)
            val rssUrls = storageService.loadRssFeeds(username).feeds
            val feedback = loadFeedback(username)
            val fetchResult = realNewsSourceService.fetchDailyNews(
                categories = categories,
                rssUrls = rssUrls,
                feedback = feedback,
                onArticle = { item ->
                    newsService.addItems(username, listOf(item))
                    log.info("Dagelijks artikel direct toegevoegd: '{}'", item.title.take(50))
                }
            )
            if (fetchResult.items.isNotEmpty()) {
                log.info("Daily Update afgerond voor {}: {} artikelen, kosten \${}", username, fetchResult.items.size, "%.4f".format(fetchResult.totalCostUsd))
            } else {
                log.warn("Daily Update afgerond voor {}: geen artikelen gevonden", username)
            }
            updateStatusDailyUpdate(username, requestId, RequestStatus.DONE, fetchResult.items.size, fetchResult.totalCostUsd, fetchResult.categoryResults)
        } catch (e: Exception) {
            log.error("Daily Update verwerking mislukt voor {}: {}", username, e.message)
            updateStatus(username, requestId, RequestStatus.FAILED)
        }
    }

    private fun updateStatus(
        username: String, id: String, status: RequestStatus,
        newItemCount: Int = 0, costUsd: Double = 0.0
    ) {
        val now = Instant.now()
        val requests = storageService.loadRequests(username).toMutableList()
        val index = requests.indexOfFirst { it.id == id }
        if (index == -1) return
        val current = requests[index]
        val isDone = status == RequestStatus.DONE || status == RequestStatus.FAILED
        val duration = if (isDone && current.processingStartedAt != null)
            (now.toEpochMilli() - Instant.parse(current.processingStartedAt).toEpochMilli()) / 1000
        else current.durationSeconds.toLong()
        val updated = current.copy(
            status = status,
            processingStartedAt = if (status == RequestStatus.PROCESSING) now.toString() else current.processingStartedAt,
            completedAt = if (isDone) now.toString() else null,
            newItemCount = if (status == RequestStatus.DONE) newItemCount else current.newItemCount,
            costUsd = if (status == RequestStatus.DONE) costUsd else current.costUsd,
            durationSeconds = if (isDone) duration.toInt() else current.durationSeconds
        )
        requests[index] = updated
        storageService.saveRequests(username, requests)
        webSocketHandler.broadcast(updated)
    }

    private fun updateStatusDailyUpdate(
        username: String, id: String, status: RequestStatus,
        newItemCount: Int, costUsd: Double, categoryResults: List<CategoryResult>
    ) {
        val now = Instant.now()
        val requests = storageService.loadRequests(username).toMutableList()
        val index = requests.indexOfFirst { it.id == id }
        if (index == -1) return
        val current = requests[index]
        val isDone = status == RequestStatus.DONE || status == RequestStatus.FAILED
        val duration = if (isDone && current.processingStartedAt != null)
            (now.toEpochMilli() - Instant.parse(current.processingStartedAt).toEpochMilli()) / 1000
        else current.durationSeconds.toLong()
        val updated = current.copy(
            status = status,
            processingStartedAt = if (status == RequestStatus.PROCESSING) now.toString() else current.processingStartedAt,
            completedAt = if (isDone) now.toString() else null,
            newItemCount = newItemCount,
            costUsd = costUsd,
            categoryResults = categoryResults,
            durationSeconds = if (isDone) duration.toInt() else current.durationSeconds
        )
        requests[index] = updated
        storageService.saveRequests(username, requests)
        webSocketHandler.broadcast(updated)
    }
}
