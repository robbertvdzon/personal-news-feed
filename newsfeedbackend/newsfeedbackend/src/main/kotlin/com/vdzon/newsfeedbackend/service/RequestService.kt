package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.CreateRequestDto
import com.vdzon.newsfeedbackend.model.NewsRequest
import com.vdzon.newsfeedbackend.model.RequestStatus
import com.vdzon.newsfeedbackend.websocket.RequestWebSocketHandler
import org.slf4j.LoggerFactory
import org.springframework.scheduling.annotation.Async
import org.springframework.stereotype.Service
import java.time.Instant
import java.util.UUID

@Service
class RequestService(
    private val storageService: StorageService,
    private val realNewsSourceService: RealNewsSourceService,
    private val settingsService: SettingsService,
    private val newsService: NewsService,
    private val webSocketHandler: RequestWebSocketHandler
) {
    private val log = LoggerFactory.getLogger(RequestService::class.java)

    fun getAll(username: String): List<NewsRequest> = storageService.loadRequests(username)

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
            newItemCount = 0
        )
        requests[index] = reset
        storageService.saveRequests(username, requests)
        webSocketHandler.broadcast(reset)
        processAsync(username, reset)
        return reset
    }

    @Async
    fun processAsync(username: String, request: NewsRequest) {
        updateStatus(username, request.id, RequestStatus.PROCESSING)
        try {
            val categories = settingsService.getSettings(username)
            val articles = realNewsSourceService.fetchArticlesForSubject(
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
            updateStatus(username, request.id, RequestStatus.DONE, articles.size)
        } catch (e: Exception) {
            log.error("Request verwerking mislukt voor {}: {}", username, e.message)
            updateStatus(username, request.id, RequestStatus.FAILED)
        }
    }

    private fun updateStatus(username: String, id: String, status: RequestStatus, newItemCount: Int = 0) {
        val requests = storageService.loadRequests(username).toMutableList()
        val index = requests.indexOfFirst { it.id == id }
        if (index == -1) return
        val updated = requests[index].copy(
            status = status,
            completedAt = if (status == RequestStatus.DONE || status == RequestStatus.FAILED) Instant.now().toString() else null,
            newItemCount = if (status == RequestStatus.DONE) newItemCount else requests[index].newItemCount
        )
        requests[index] = updated
        storageService.saveRequests(username, requests)
        webSocketHandler.broadcast(updated)
    }

    private fun saveRequest(username: String, request: NewsRequest) {
        val requests = storageService.loadRequests(username).toMutableList()
        requests.add(0, request)
        storageService.saveRequests(username, requests)
    }
}
