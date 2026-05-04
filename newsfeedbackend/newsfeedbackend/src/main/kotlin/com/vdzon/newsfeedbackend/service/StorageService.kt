package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.CategorySettings
import com.vdzon.newsfeedbackend.model.NewsItem
import com.vdzon.newsfeedbackend.model.NewsRequest
import com.vdzon.newsfeedbackend.model.Podcast
import com.vdzon.newsfeedbackend.model.TopicEntry
import com.vdzon.newsfeedbackend.model.User
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
    // ── user registry ──────────────────────────────────────────────────────────
    private val usersFile get() = dataFile("users.json")

    fun loadUsers(): List<User> = readFile(usersFile) ?: emptyList()
    fun saveUsers(users: List<User>) = objectMapper.writeValue(usersFile, users)
    fun getAllUsernames(): List<String> =
        File(dataDir, "users").let { if (it.isDirectory) it.list()?.toList() ?: emptyList() else emptyList() }

    // ── per-user news ──────────────────────────────────────────────────────────
    fun loadNews(username: String): List<NewsItem> = readFile(userFile(username, "news_items.json")) ?: emptyList()
    fun saveNews(username: String, items: List<NewsItem>) = objectMapper.writeValue(userFile(username, "news_items.json"), items)

    // ── per-user requests ──────────────────────────────────────────────────────
    fun loadRequests(username: String): List<NewsRequest> = readFile(userFile(username, "news_requests.json")) ?: emptyList()
    fun saveRequests(username: String, requests: List<NewsRequest>) = objectMapper.writeValue(userFile(username, "news_requests.json"), requests)

    // ── per-user settings ──────────────────────────────────────────────────────
    fun loadSettings(username: String): List<CategorySettings>? = readFile(userFile(username, "settings.json"))
    fun saveSettings(username: String, settings: List<CategorySettings>) = objectMapper.writeValue(userFile(username, "settings.json"), settings)

    // ── per-user podcasts ──────────────────────────────────────────────────────
    fun loadPodcasts(username: String): List<Podcast> = readFile(userFile(username, "podcasts.json")) ?: emptyList()
    fun savePodcasts(username: String, podcasts: List<Podcast>) = objectMapper.writeValue(userFile(username, "podcasts.json"), podcasts)

    // ── per-user topic history ─────────────────────────────────────────────────
    fun loadTopicHistory(username: String): List<TopicEntry> = readFile(userFile(username, "topic_history.json")) ?: emptyList()
    fun saveTopicHistory(username: String, entries: List<TopicEntry>) = objectMapper.writeValue(userFile(username, "topic_history.json"), entries)

    fun audioDirForUser(username: String): File {
        val dir = File(dataDir, "users/$username/audio")
        dir.mkdirs()
        return dir
    }

    // ── helpers ────────────────────────────────────────────────────────────────
    private fun userFile(username: String, name: String): File {
        val dir = File(dataDir, "users/$username")
        dir.mkdirs()
        return File(dir, name)
    }

    private fun dataFile(name: String): File {
        File(dataDir).mkdirs()
        return File(dataDir, name)
    }

    private inline fun <reified T> readFile(file: File): T? {
        if (!file.exists()) return null
        return try { objectMapper.readValue<T>(file) } catch (e: Exception) { null }
    }
}
