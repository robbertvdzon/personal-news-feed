package com.vdzon.newsfeedbackend.model

data class NewsRequest(
    val id: String,
    val subject: String,
    val sourceItemId: String? = null,
    val sourceItemTitle: String? = null,
    val preferredCount: Int = 2,
    val maxCount: Int = 5,
    val extraInstructions: String = "",
    val status: RequestStatus = RequestStatus.PENDING,
    val createdAt: String,
    val completedAt: String? = null,
    val newItemCount: Int = 0
)
