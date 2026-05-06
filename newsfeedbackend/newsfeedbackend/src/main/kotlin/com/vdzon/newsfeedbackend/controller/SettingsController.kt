package com.vdzon.newsfeedbackend.controller

import com.vdzon.newsfeedbackend.model.CategorySettings
import com.vdzon.newsfeedbackend.service.SettingsService
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PutMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/settings")
class SettingsController(private val settingsService: SettingsService) {

    @GetMapping
    fun getSettings(auth: Authentication): List<CategorySettings> =
        settingsService.getSettings(auth.name)

    @PutMapping
    fun saveSettings(auth: Authentication, @RequestBody categories: List<CategorySettings>): List<CategorySettings> {
        settingsService.saveSettings(auth.name, categories)
        return categories
    }
}
