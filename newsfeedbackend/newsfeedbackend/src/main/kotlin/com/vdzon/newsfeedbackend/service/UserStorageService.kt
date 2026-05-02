package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.User
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service
import tools.jackson.databind.ObjectMapper
import tools.jackson.module.kotlin.readValue
import java.io.File

@Service
class UserStorageService(
    private val objectMapper: ObjectMapper,
    @Value("\${app.data-dir:./data}") private val dataDir: String
) {
    private val usersFile get() = File(dataDir, "users.json").also { it.parentFile.mkdirs() }

    fun findByUsername(username: String): User? =
        loadAll().find { it.username == username }

    fun existsByUsername(username: String): Boolean =
        loadAll().any { it.username == username }

    fun save(user: User) {
        val users = loadAll().toMutableList()
        users.add(user)
        objectMapper.writeValue(usersFile, users)
    }

    private fun loadAll(): List<User> {
        if (!usersFile.exists()) return emptyList()
        return try {
            objectMapper.readValue(usersFile)
        } catch (e: Exception) {
            emptyList()
        }
    }
}
