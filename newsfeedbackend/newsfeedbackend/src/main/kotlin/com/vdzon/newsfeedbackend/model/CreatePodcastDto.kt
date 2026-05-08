package com.vdzon.newsfeedbackend.model

data class CreatePodcastDto(
    val periodDays: Int = 7,
    val durationMinutes: Int = 10,
    val customTopics: List<String> = emptyList(),
    val ttsProvider: TtsProvider = TtsProvider.OPENAI
)
