package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.CategorySettings
import org.springframework.stereotype.Service

@Service
class SettingsService(
    private val storageService: StorageService,
    private val anthropicService: AnthropicService
) {

    fun getSettings(username: String): List<CategorySettings> =
        storageService.loadSettings(username) ?: defaultCategories()

    fun saveSettings(username: String, categories: List<CategorySettings>) =
        storageService.saveSettings(username, categories)

    fun suggestWebsites(username: String, categoryId: String): List<String> {
        val categories = getSettings(username)
        val cat = categories.firstOrNull { it.id == categoryId } ?: return emptyList()
        val suggested = anthropicService.suggestWebsites(cat.name, cat.extraInstructions)
        if (suggested.isNotEmpty()) {
            // Sla de suggesties op (bestaande websites samenvoegen)
            val updated = categories.map { c ->
                if (c.id == categoryId) c.copy(websites = (c.websites + suggested).distinct()) else c
            }
            storageService.saveSettings(username, updated)
        }
        return suggested
    }

    private fun defaultCategories() = listOf(
        CategorySettings("kotlin", "Kotlin", enabled = true, isSystem = false, preferredCount = 3, maxCount = 5,
            websites = listOf("blog.jetbrains.com", "kotlinweekly.net", "kotlin.link", "betterprogramming.pub", "proandroiddev.com")),
        CategorySettings("flutter", "Flutter", enabled = true, isSystem = false, preferredCount = 3, maxCount = 5,
            websites = listOf("flutter.dev", "medium.flutter.dev", "flutterweekly.net", "codewithandrea.com", "riverpod.dev")),
        CategorySettings("ai", "Artificiële Intelligentie", enabled = true, isSystem = false, preferredCount = 3, maxCount = 5,
            websites = listOf("the-decoder.com", "simonwillison.net", "artificialintelligence-news.com", "venturebeat.com", "techcrunch.com")),
        CategorySettings("blockchain", "Blockchain", enabled = false, isSystem = false, preferredCount = 3, maxCount = 5,
            websites = listOf("coindesk.com", "theblock.co", "decrypt.co", "cointelegraph.com")),
        CategorySettings("spring", "Spring", enabled = true, isSystem = false, preferredCount = 3, maxCount = 5,
            websites = listOf("spring.io", "reflectoring.io", "baeldung.com", "bootify.io", "digma.ai")),
        CategorySettings("web_dev", "Web Development", enabled = true, isSystem = false, preferredCount = 3, maxCount = 5,
            websites = listOf("web.dev", "css-tricks.com", "smashingmagazine.com", "thenewstack.io", "frontendmasters.com")),
        CategorySettings("overig", "Overig", enabled = true, isSystem = true),
        CategorySettings("dagelijks-overzicht", "Dagelijks overzicht", enabled = true, isSystem = true),
    )
}
