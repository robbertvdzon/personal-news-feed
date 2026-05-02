package com.vdzon.newsfeedbackend.model

data class NewsItem(
    val id: String,
    val title: String,
    val summary: String,
    val url: String,
    val category: String,
    val timestamp: String,
    val source: String
)
