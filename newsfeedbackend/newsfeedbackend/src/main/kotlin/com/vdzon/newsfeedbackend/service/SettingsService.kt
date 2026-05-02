package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.CategorySettings
import org.springframework.stereotype.Service

@Service
class SettingsService(private val storageService: StorageService) {

    fun getSettings(username: String): List<CategorySettings> =
        storageService.loadSettings(username) ?: defaultCategories()

    fun saveSettings(username: String, categories: List<CategorySettings>) =
        storageService.saveSettings(username, categories)

    private fun defaultCategories() = listOf(
        CategorySettings("kotlin",     "Kotlin",                    enabled = true,  isSystem = false, preferredCount = 3, maxCount = 5),
        CategorySettings("flutter",    "Flutter",                   enabled = true,  isSystem = false, preferredCount = 3, maxCount = 5),
        CategorySettings("ai",         "Artificiële Intelligentie", enabled = true,  isSystem = false, preferredCount = 3, maxCount = 5),
        CategorySettings("blockchain", "Blockchain",                enabled = false, isSystem = false, preferredCount = 3, maxCount = 5),
        CategorySettings("spring",     "Spring",                    enabled = true,  isSystem = false, preferredCount = 3, maxCount = 5),
        CategorySettings("web_dev",    "Web Development",           enabled = true,  isSystem = false, preferredCount = 3, maxCount = 5),
        CategorySettings("overig",     "Overig",                    enabled = true,  isSystem = true),
    )
}
