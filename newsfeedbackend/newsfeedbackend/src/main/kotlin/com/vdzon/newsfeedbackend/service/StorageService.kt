package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.NewsItem
import com.vdzon.newsfeedbackend.model.NewsRequest
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service
import tools.jackson.databind.ObjectMapper
import tools.jackson.module.kotlin.readValue
import java.io.File

@Service
class StorageService(
    private val objectMapper: ObjectMapper,
    @Value("\${app.data-dir:./data}") private val dataDir: String
) {
    private val newsFile get() = File(dataDir, "news_items.json").also { it.parentFile.mkdirs() }
    private val requestsFile get() = File(dataDir, "news_requests.json").also { it.parentFile.mkdirs() }

    fun loadNews(): List<NewsItem> {
        if (!newsFile.exists()) return emptyList()
        return try {
            objectMapper.readValue(newsFile)
        } catch (e: Exception) {
            emptyList()
        }
    }

    fun saveNews(items: List<NewsItem>) {
        objectMapper.writeValue(newsFile, items)
    }

    fun loadRequests(): List<NewsRequest> {
        if (!requestsFile.exists()) return emptyList()
        return try {
            objectMapper.readValue(requestsFile)
        } catch (e: Exception) {
            emptyList()
        }
    }

    fun saveRequests(requests: List<NewsRequest>) {
        objectMapper.writeValue(requestsFile, requests)
    }
}
