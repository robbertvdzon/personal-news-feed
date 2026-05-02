package com.vdzon.newsfeedbackend.service

import org.slf4j.LoggerFactory
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Service

@Service
class DailyUpdateScheduler(
    private val requestService: RequestService,
    private val storageService: StorageService
) {
    private val log = LoggerFactory.getLogger(DailyUpdateScheduler::class.java)

    @Scheduled(cron = "0 0 6 * * *")
    fun scheduledDailyUpdate() {
        log.info("Dagelijkse Update gestart voor alle gebruikers")
        storageService.getAllUsernames().forEach { username ->
            log.info("Daily Update starten voor: {}", username)
            requestService.runDailyUpdate(username)
        }
    }
}
