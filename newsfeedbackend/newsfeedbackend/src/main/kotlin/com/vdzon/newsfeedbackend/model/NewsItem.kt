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
    val liked: Boolean? = null,   // null = geen feedback, true = geliked, false = gedisliked
    val isSummary: Boolean = false,
    /** Canonieke onderwerpen geëxtraheerd door Claude — gebruikt voor topic-geschiedenis */
    val topics: List<String> = emptyList(),
    /** Originele publicatiedatum van het artikel (van de bron), bijv. "2025-05-04" */
    val publishedDate: String? = null
)
