package com.vdzon.newsfeedbackend.controller

import com.vdzon.newsfeedbackend.api.SettingsApi
import com.vdzon.newsfeedbackend.model.CategorySettings
import com.vdzon.newsfeedbackend.service.SettingsService
import org.springframework.http.ResponseEntity
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.web.bind.annotation.RestController

@RestController
class SettingsController(private val settingsService: SettingsService) : SettingsApi {

    private val username get() = SecurityContextHolder.getContext().authentication!!.name

    override fun getSettings(): ResponseEntity<List<CategorySettings>> =
        ResponseEntity.ok(settingsService.getSettings(username))

    override fun saveSettings(categorySettings: List<CategorySettings>): ResponseEntity<List<CategorySettings>> {
        settingsService.saveSettings(username, categorySettings)
        return ResponseEntity.ok(categorySettings)
    }
}
