package com.vdzon.newsfeedbackend.model

enum class PodcastStatus {
    PENDING, GENERATING_SCRIPT, GENERATING_AUDIO, DONE, FAILED
}

data class Podcast(
    val id: String,
    val title: String,
    val periodDescription: String,
    val periodDays: Int,
    val durationMinutes: Int,
    val status: PodcastStatus = PodcastStatus.PENDING,
    val createdAt: String,
    val scriptText: String? = null,
    val audioPath: String? = null,
    val durationSeconds: Int? = null,
    val costUsd: Double = 0.0
)
