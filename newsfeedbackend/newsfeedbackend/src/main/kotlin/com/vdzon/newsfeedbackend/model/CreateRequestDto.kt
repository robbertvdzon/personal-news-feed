package com.vdzon.newsfeedbackend.model

data class CreateRequestDto(
    val subject: String,
    val sourceItemId: String? = null,
    val sourceItemTitle: String? = null,
    val preferredCount: Int = 2,
    val maxCount: Int = 5
)
