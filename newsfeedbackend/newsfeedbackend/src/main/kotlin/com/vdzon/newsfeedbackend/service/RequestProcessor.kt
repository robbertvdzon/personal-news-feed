package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.CategoryResult
import com.vdzon.newsfeedbackend.model.FeedItem
import com.vdzon.newsfeedbackend.model.NewsRequest
import com.vdzon.newsfeedbackend.model.RequestStatus
import com.vdzon.newsfeedbackend.model.RssItem
import com.vdzon.newsfeedbackend.websocket.RequestWebSocketHandler
import org.slf4j.LoggerFactory
import org.springframework.scheduling.annotation.Async
import org.springframework.stereotype.Service
import java.time.Instant
import java.util.Collections
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

@Service
class RequestProcessor(
    private val storageService: StorageService,
    private val realNewsSourceService: RealNewsSourceService,
    private val settingsService: SettingsService,
    private val rssItemService: RssItemService,
    private val feedItemService: FeedItemService,
    private val rssProcessingService: RssProcessingService,
    private val anthropicService: AnthropicService,
    private val topicHistoryService: TopicHistoryService,
    private val webSocketHandler: RequestWebSocketHandler
) {
    // Set met request-IDs die gecanceld zijn; wordt gecheckt in de processing loops
    private val cancelledIds: MutableSet<String> = Collections.newSetFromMap(ConcurrentHashMap())

    fun markCancelled(id: String) {
        cancelledIds.add(id)
    }

    private fun isCancelled(id: String) = cancelledIds.contains(id)

    private fun loadFeedback(username: String): FeedbackContext {
        val liked = rssItemService.getLikedItems(username).map { it.title }
        val disliked = rssItemService.getDislikedItems(username).map { it.title }
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
            val existingUrls = rssItemService.getAll(username).map { it.url }.toSet()
            val nowStr = Instant.now().toString()
            var addedCount = 0
            val (articles, costUsd) = realNewsSourceService.fetchArticlesForSubject(
                subject = request.subject,
                preferredCount = request.preferredCount,
                extraInstructions = request.extraInstructions,
                maxAgeDays = request.maxAgeDays,
                categories = categories,
                rssUrls = rssUrls,
                feedback = feedback,
                existingUrls = existingUrls,
                onArticle = { item ->
                    if (!isCancelled(request.id)) {
                        val feedItem = FeedItem(
                            id = item.id,
                            title = item.title,
                            summary = item.summary,
                            url = item.url,
                            category = item.category,
                            source = item.source,
                            sourceUrls = listOf(item.url),
                            sourceRssIds = emptyList(),
                            topics = item.topics,
                            feedReason = "Gevraagd via verzoek: ${request.subject}",
                            createdAt = nowStr,
                            publishedDate = item.publishedDate
                        )
                        feedItemService.addItem(username, feedItem)
                        addedCount++
                        log.info("Verzoek-artikel direct toegevoegd als FeedItem: '{}'", item.title.take(50))
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
            val newCount = rssProcessingService.processUser(username)
            if (isCancelled(requestId)) {
                log.info("Daily Update geannuleerd voor {}", username)
                cancelledIds.remove(requestId)
                return
            }
            if (newCount > 0) {
                log.info("Daily Update afgerond voor {}: {} nieuwe items", username, newCount)
            } else {
                log.info("Daily Update afgerond voor {}: geen nieuwe items", username)
            }
            updateStatusDailyUpdate(username, requestId, RequestStatus.DONE, newCount, 0.0, emptyList())
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

    @Async
    fun processDailySummary(username: String, requestId: String) {
        if (isCancelled(requestId)) return
        updateStatus(username, requestId, RequestStatus.PROCESSING)
        try {
            val categories = settingsService.getSettings(username)
            val cutoff24h = java.time.Instant.now().minusSeconds(24 * 3600).toString()
            val cutoff7d = java.time.Instant.now().minusSeconds(7 * 24 * 3600).toString()
            val feedItems = feedItemService.getAll(username)
                .filter { it.createdAt >= cutoff24h }
                .sortedByDescending { it.createdAt }
            val allRssItems = rssItemService.getAll(username)
                .filter { it.timestamp >= cutoff7d }
                .sortedByDescending { it.timestamp }
            val likedTitles = rssItemService.getLikedItems(username).map { it.title }.take(20)
            val topicHistoryContext = topicHistoryService.buildNewsContext(username)

            val (summaryText, cost) = anthropicService.generateDailySummaryFromRss(
                feedItems = feedItems,
                allRssItems = allRssItems,
                categories = categories,
                likedTitles = likedTitles,
                topicHistoryContext = topicHistoryContext
            )

            log.info("Dagelijkse samenvatting gegenereerd voor {}: {} tekens, \${}",
                username, summaryText.length, "%.4f".format(cost))

            updateStatusDailySummary(username, requestId, RequestStatus.DONE, summaryText, cost)
        } catch (e: Exception) {
            if (isCancelled(requestId)) {
                log.info("Dagelijkse samenvatting geannuleerd voor {}", username)
                cancelledIds.remove(requestId)
            } else {
                log.error("Dagelijkse samenvatting mislukt voor {}: {}", username, e.message)
                updateStatus(username, requestId, RequestStatus.FAILED)
            }
        }
    }

    private fun updateStatusDailySummary(
        username: String, id: String, status: RequestStatus,
        summaryText: String, costUsd: Double
    ) {
        val now = Instant.now()
        val requests = storageService.loadRequests(username).toMutableList()
        val index = requests.indexOfFirst { it.id == id }
        if (index == -1) return
        val current = requests[index]
        if (current.status == RequestStatus.CANCELLED) return
        val isDone = status == RequestStatus.DONE || status == RequestStatus.FAILED
        val duration = if (isDone && current.processingStartedAt != null)
            (now.toEpochMilli() - Instant.parse(current.processingStartedAt).toEpochMilli()) / 1000
        else current.durationSeconds.toLong()
        val updated = current.copy(
            status = status,
            processingStartedAt = if (status == RequestStatus.PROCESSING) now.toString() else current.processingStartedAt,
            completedAt = if (isDone) now.toString() else null,
            summaryText = summaryText,
            costUsd = costUsd,
            durationSeconds = if (isDone) duration.toInt() else current.durationSeconds
        )
        requests[index] = updated
        storageService.saveRequests(username, requests)
        webSocketHandler.broadcast(updated)
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
