package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.CategoryResult
import com.vdzon.newsfeedbackend.model.NewsRequest
import com.vdzon.newsfeedbackend.model.RequestStatus
import com.vdzon.newsfeedbackend.websocket.RequestWebSocketHandler
import org.slf4j.LoggerFactory
import org.springframework.scheduling.annotation.Async
import org.springframework.stereotype.Service
import java.time.Instant
import java.util.Collections
import java.util.concurrent.ConcurrentHashMap

@Service
class RequestProcessor(
    private val storageService: StorageService,
    private val realNewsSourceService: RealNewsSourceService,
    private val settingsService: SettingsService,
    private val newsService: NewsService,
    private val webSocketHandler: RequestWebSocketHandler
) {
    // Set met request-IDs die gecanceld zijn; wordt gecheckt in de processing loops
    private val cancelledIds: MutableSet<String> = Collections.newSetFromMap(ConcurrentHashMap())

    fun markCancelled(id: String) {
        cancelledIds.add(id)
    }

    private fun isCancelled(id: String) = cancelledIds.contains(id)

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
        if (isCancelled(request.id)) return
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
                    if (!isCancelled(request.id)) {
                        newsService.addItems(username, listOf(item))
                        log.info("Artikel direct toegevoegd: '{}'", item.title.take(50))
                    }
                }
            )
            if (isCancelled(request.id)) {
                log.info("Verzoek '{}' geannuleerd voor {}", request.subject, username)
                cancelledIds.remove(request.id)
                return
            }
            if (articles.isNotEmpty()) {
                log.info("Verzoek '{}' afgerond voor {}: {} artikelen", request.subject, username, articles.size)
            } else {
                log.warn("Verzoek '{}' afgerond voor {}: geen artikelen gevonden", request.subject, username)
            }
            updateStatus(username, request.id, RequestStatus.DONE, articles.size, costUsd)
        } catch (e: Exception) {
            if (isCancelled(request.id)) {
                log.info("Verzoek '{}' geannuleerd voor {}", request.subject, username)
                cancelledIds.remove(request.id)
            } else {
                log.error("Request verwerking mislukt voor {}: {}", username, e.message)
                updateStatus(username, request.id, RequestStatus.FAILED)
            }
        }
    }

    @Async
    fun processDailyUpdate(username: String, requestId: String) {
        if (isCancelled(requestId)) return
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
                    if (!isCancelled(requestId)) {
                        newsService.addItems(username, listOf(item))
                        log.info("Dagelijks artikel direct toegevoegd: '{}'", item.title.take(50))
                    }
                }
            )
            if (isCancelled(requestId)) {
                log.info("Daily Update geannuleerd voor {}", username)
                cancelledIds.remove(requestId)
                return
            }
            if (fetchResult.items.isNotEmpty()) {
                log.info("Daily Update afgerond voor {}: {} artikelen, kosten \${}", username, fetchResult.items.size, "%.4f".format(fetchResult.totalCostUsd))
            } else {
                log.warn("Daily Update afgerond voor {}: geen artikelen gevonden", username)
            }
            updateStatusDailyUpdate(username, requestId, RequestStatus.DONE, fetchResult.items.size, fetchResult.totalCostUsd, fetchResult.categoryResults)
        } catch (e: Exception) {
            if (isCancelled(requestId)) {
                log.info("Daily Update geannuleerd voor {}", username)
                cancelledIds.remove(requestId)
            } else {
                log.error("Daily Update verwerking mislukt voor {}: {}", username, e.message)
                updateStatus(username, requestId, RequestStatus.FAILED)
            }
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
        if (current.status == RequestStatus.CANCELLED) return  // nooit overschrijven
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
        if (current.status == RequestStatus.CANCELLED) return  // nooit overschrijven
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
