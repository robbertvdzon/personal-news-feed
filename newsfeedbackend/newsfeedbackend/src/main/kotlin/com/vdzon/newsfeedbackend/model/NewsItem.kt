package com.vdzon.newsfeedbackend.model

data class NewsItem(
    val id: String,
    val title: String,
    val summary: String,
    val url: String,
    val category: String,
    val timestamp: String,
    val source: String,
    val isRead: Boolean = false,
    val starred: Boolean = false,
    val liked: Boolean? = null   // null = geen feedback, true = geliked, false = gedisliked
)
