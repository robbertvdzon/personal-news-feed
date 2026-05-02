package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.CreateRequestDto
import com.vdzon.newsfeedbackend.model.NewsRequest
import com.vdzon.newsfeedbackend.model.RequestStatus
import com.vdzon.newsfeedbackend.websocket.RequestWebSocketHandler
import org.springframework.scheduling.annotation.Async
import org.springframework.stereotype.Service
import java.time.Instant
import java.util.UUID

@Service
class RequestService(
    private val storageService: StorageService,
    private val mockNewsService: MockNewsService,
    private val newsService: NewsService,
    private val webSocketHandler: RequestWebSocketHandler
) {
    fun getAll(): List<NewsRequest> = storageService.loadRequests()

    fun create(dto: CreateRequestDto): NewsRequest {
        val request = NewsRequest(
            id = UUID.randomUUID().toString(),
            subject = dto.subject,
            sourceItemId = dto.sourceItemId,
            sourceItemTitle = dto.sourceItemTitle,
            preferredCount = dto.preferredCount,
            maxCount = dto.maxCount,
            status = RequestStatus.PENDING,
            createdAt = Instant.now().toString()
        )
        saveRequest(request)
        processAsync(request)
        return request
    }

    @Async
    fun processAsync(request: NewsRequest) {
        updateStatus(request.id, RequestStatus.PROCESSING)

        try {
            val articles = mockNewsService.fetchArticlesForSubject(
                request.subject,
                request.preferredCount
            )
            newsService.addItems(articles)
            updateStatus(request.id, RequestStatus.DONE, articles.size)
        } catch (e: Exception) {
            updateStatus(request.id, RequestStatus.FAILED)
        }
    }

    private fun updateStatus(id: String, status: RequestStatus, newItemCount: Int = 0) {
        val requests = storageService.loadRequests().toMutableList()
        val index = requests.indexOfFirst { it.id == id }
        if (index == -1) return

        val updated = requests[index].copy(
            status = status,
            completedAt = if (status == RequestStatus.DONE || status == RequestStatus.FAILED)
                Instant.now().toString() else null,
            newItemCount = if (status == RequestStatus.DONE) newItemCount else requests[index].newItemCount
        )
        requests[index] = updated
        storageService.saveRequests(requests)
        webSocketHandler.broadcast(updated)
    }

    private fun saveRequest(request: NewsRequest) {
        val requests = storageService.loadRequests().toMutableList()
        requests.add(0, request)
        storageService.saveRequests(requests)
    }
}
