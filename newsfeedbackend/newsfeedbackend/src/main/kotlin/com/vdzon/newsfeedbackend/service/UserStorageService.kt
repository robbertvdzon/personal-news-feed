package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.User
import org.springframework.stereotype.Service

@Service
class UserStorageService(private val storageService: StorageService) {

    fun findByUsername(username: String): User? = storageService.loadUsers().find { it.username == username }
    fun existsByUsername(username: String): Boolean = storageService.loadUsers().any { it.username == username }

    fun save(user: User) {
        val users = storageService.loadUsers().toMutableList()
        users.add(user)
        storageService.saveUsers(users)
    }
}
