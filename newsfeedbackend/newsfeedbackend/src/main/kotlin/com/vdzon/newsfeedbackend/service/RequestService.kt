package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.CreateRequestDto
import com.vdzon.newsfeedbackend.model.NewsRequest
import com.vdzon.newsfeedbackend.model.RequestStatus
import com.vdzon.newsfeedbackend.websocket.RequestWebSocketHandler
import jakarta.annotation.PostConstruct
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import java.time.Instant
import java.util.UUID

const val DAILY_UPDATE_ID_PREFIX = "daily-update-"

@Service
class RequestService(
    private val storageService: StorageService,
    private val requestProcessor: RequestProcessor,
    private val webSocketHandler: RequestWebSocketHandler
) {
    private val log = LoggerFactory.getLogger(RequestService::class.java)

    @PostConstruct
    fun resetStuckRequests() {
        val usernames = storageService.getAllUsernames()
        for (username in usernames) {
            val requests = storageService.loadRequests(username).toMutableList()
            val stuck = requests.filter { it.status == RequestStatus.PROCESSING || it.status == RequestStatus.PENDING }
            if (stuck.isEmpty()) continue
            val reset = requests.map { req ->
                if (req.status == RequestStatus.PROCESSING || req.status == RequestStatus.PENDING)
                    req.copy(status = RequestStatus.FAILED, completedAt = Instant.now().toString())
                else req
            }
            storageService.saveRequests(username, reset)
            log.info("Herstart: {} vastgelopen verzoeken gereset naar FAILED voor {}", stuck.size, username)
        }
    }

    fun cancel(username: String, id: String) {
        val requests = storageService.loadRequests(username).toMutableList()
        val index = requests.indexOfFirst { it.id == id }
        if (index == -1) return
        val current = requests[index]
        if (current.status != RequestStatus.PROCESSING && current.status != RequestStatus.PENDING) return
        // Markeer direct als CANCELLED in storage zodat de UI het ziet
        val cancelled = current.copy(status = RequestStatus.CANCELLED, completedAt = Instant.now().toString())
        requests[index] = cancelled
        storageService.saveRequests(username, requests)
        webSocketHandler.broadcast(cancelled)
        // Signaleer de achtergrondthread om te stoppen
        requestProcessor.markCancelled(id)
        log.info("Verzoek '{}' geannuleerd voor {}", current.subject, username)
    }

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
            maxAgeDays = dto.maxAgeDays,
            status = RequestStatus.PENDING,
            createdAt = Instant.now().toString()
        )
        saveRequest(username, request)
        requestProcessor.processRequest(username, request)  // via aparte bean → @Async werkt
        return request
    }

    fun delete(username: String, id: String) {
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
            requestProcessor.processDailyUpdate(username, reset.id)
        } else {
            requestProcessor.processRequest(username, reset)
        }
        return reset
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
        requestProcessor.processDailyUpdate(username, reset.id)
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

    private fun saveRequest(username: String, request: NewsRequest) {
        val requests = storageService.loadRequests(username).toMutableList()
        val insertAt = if (requests.isNotEmpty() && requests[0].isDailyUpdate) 1 else 0
        requests.add(insertAt, request)
        storageService.saveRequests(username, requests)
    }
}
