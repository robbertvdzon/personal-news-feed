package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.CategoryResult
import com.vdzon.newsfeedbackend.model.CreateRequestDto
import com.vdzon.newsfeedbackend.model.NewsRequest
import com.vdzon.newsfeedbackend.model.RequestStatus
import com.vdzon.newsfeedbackend.websocket.RequestWebSocketHandler
import org.slf4j.LoggerFactory
import org.springframework.scheduling.annotation.Async
import org.springframework.stereotype.Service
import java.time.Instant
import java.util.UUID

const val DAILY_UPDATE_ID_PREFIX = "daily-update-"

@Service
class RequestService(
    private val storageService: StorageService,
    private val realNewsSourceService: RealNewsSourceService,
    private val settingsService: SettingsService,
    private val newsService: NewsService,
    private val webSocketHandler: RequestWebSocketHandler
) {
    private val log = LoggerFactory.getLogger(RequestService::class.java)

    fun getAll(username: String): List<NewsRequest> {
        ensureDailyUpdateExists(username)
        return storageService.loadRequests(username)
    }

    fun create(username: String, dto: CreateRequestDto): NewsRequest {
        val request = NewsRequest(
            id = UUID.randomUUID().toString(),
            subject = dto.subject,
            sourceItemId = dto.sourceItemId,
            sourceItemTitle = dto.sourceItemTitle,
            preferredCount = dto.preferredCount,
            maxCount = dto.maxCount,
            extraInstructions = dto.extraInstructions,
            status = RequestStatus.PENDING,
            createdAt = Instant.now().toString()
        )
        saveRequest(username, request)
        processAsync(username, request)
        return request
    }

    fun delete(username: String, id: String) {
        // Daily Update mag niet worden verwijderd
        if (id.startsWith(DAILY_UPDATE_ID_PREFIX)) return
        val requests = storageService.loadRequests(username).toMutableList()
        requests.removeIf { it.id == id }
        storageService.saveRequests(username, requests)
    }

    fun rerun(username: String, id: String): NewsRequest {
        val requests = storageService.loadRequests(username).toMutableList()
        val index = requests.indexOfFirst { it.id == id }
        if (index == -1) throw IllegalArgumentException("Request niet gevonden: $id")
        val reset = requests[index].copy(
            status = RequestStatus.PENDING,
            completedAt = null,
            newItemCount = 0,
            costUsd = 0.0,
            categoryResults = emptyList()
        )
        requests[index] = reset
        storageService.saveRequests(username, requests)
        webSocketHandler.broadcast(reset)

        if (reset.isDailyUpdate) {
            processDailyUpdateAsync(username, reset.id)
        } else {
            processAsync(username, reset)
        }
        return reset
    }

    @Async
    fun processAsync(username: String, request: NewsRequest) {
        updateStatus(username, request.id, RequestStatus.PROCESSING)
        try {
            val categories = settingsService.getSettings(username)
            val (articles, costUsd) = realNewsSourceService.fetchArticlesForSubject(
                subject = request.subject,
                preferredCount = request.preferredCount,
                extraInstructions = request.extraInstructions,
                categories = categories
            )
            if (articles.isNotEmpty()) {
                newsService.addItems(username, articles)
                log.info("Verzoek '{}' afgerond voor {}: {} artikelen gevonden", request.subject, username, articles.size)
            } else {
                log.warn("Verzoek '{}' afgerond voor {}: geen relevante artikelen gevonden", request.subject, username)
            }
            updateStatus(username, request.id, RequestStatus.DONE, articles.size, costUsd)
        } catch (e: Exception) {
            log.error("Request verwerking mislukt voor {}: {}", username, e.message)
            updateStatus(username, request.id, RequestStatus.FAILED)
        }
    }

    @Async
    fun processDailyUpdateAsync(username: String, requestId: String) {
        updateStatus(username, requestId, RequestStatus.PROCESSING)
        try {
            val categories = settingsService.getSettings(username)
            val fetchResult = realNewsSourceService.fetchDailyNews(categories)

            if (fetchResult.items.isNotEmpty()) {
                newsService.addItems(username, fetchResult.items)
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

    fun runDailyUpdate(username: String) {
        ensureDailyUpdateExists(username)
        val requests = storageService.loadRequests(username)
        val dailyUpdate = requests.firstOrNull { it.isDailyUpdate } ?: return
        val reset = dailyUpdate.copy(
            status = RequestStatus.PENDING,
            completedAt = null,
            newItemCount = 0,
            costUsd = 0.0,
            categoryResults = emptyList()
        )
        val updated = requests.toMutableList()
        val index = updated.indexOfFirst { it.isDailyUpdate }
        updated[index] = reset
        storageService.saveRequests(username, updated)
        webSocketHandler.broadcast(reset)
        processDailyUpdateAsync(username, reset.id)
    }

    private fun ensureDailyUpdateExists(username: String) {
        val requests = storageService.loadRequests(username)
        if (requests.none { it.isDailyUpdate }) {
            val dailyUpdate = NewsRequest(
                id = "$DAILY_UPDATE_ID_PREFIX$username",
                subject = "Dagelijkse Update",
                preferredCount = 5,
                maxCount = 10,
                isDailyUpdate = true,
                status = RequestStatus.PENDING,
                createdAt = Instant.now().toString()
            )
            val newList = mutableListOf(dailyUpdate)
            newList.addAll(requests)
            storageService.saveRequests(username, newList)
            log.info("Daily Update aangemaakt voor {}", username)
        }
    }

    private fun updateStatus(
        username: String,
        id: String,
        status: RequestStatus,
        newItemCount: Int = 0,
        costUsd: Double = 0.0
    ) {
        val requests = storageService.loadRequests(username).toMutableList()
        val index = requests.indexOfFirst { it.id == id }
        if (index == -1) return
        val updated = requests[index].copy(
            status = status,
            completedAt = if (status == RequestStatus.DONE || status == RequestStatus.FAILED) Instant.now().toString() else null,
            newItemCount = if (status == RequestStatus.DONE) newItemCount else requests[index].newItemCount,
            costUsd = if (status == RequestStatus.DONE) costUsd else requests[index].costUsd
        )
        requests[index] = updated
        storageService.saveRequests(username, requests)
        webSocketHandler.broadcast(updated)
    }

    private fun updateStatusDailyUpdate(
        username: String,
        id: String,
        status: RequestStatus,
        newItemCount: Int,
        costUsd: Double,
        categoryResults: List<CategoryResult>
    ) {
        val requests = storageService.loadRequests(username).toMutableList()
        val index = requests.indexOfFirst { it.id == id }
        if (index == -1) return
        val updated = requests[index].copy(
            status = status,
            completedAt = if (status == RequestStatus.DONE || status == RequestStatus.FAILED) Instant.now().toString() else null,
            newItemCount = newItemCount,
            costUsd = costUsd,
            categoryResults = categoryResults
        )
        requests[index] = updated
        storageService.saveRequests(username, requests)
        webSocketHandler.broadcast(updated)
    }

    private fun saveRequest(username: String, request: NewsRequest) {
        val requests = storageService.loadRequests(username).toMutableList()
        // Voeg toe na de Daily Update (die staat altijd bovenaan)
        val insertAt = if (requests.isNotEmpty() && requests[0].isDailyUpdate) 1 else 0
        requests.add(insertAt, request)
        storageService.saveRequests(username, requests)
    }
}
