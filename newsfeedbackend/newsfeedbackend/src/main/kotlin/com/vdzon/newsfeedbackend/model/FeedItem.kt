package com.vdzon.newsfeedbackend.model

data class FeedItem(
    val id: String,
    val title: String,
    val summary: String,           // uitgebreide samenvatting (400-600 woorden)
    val url: String = "",          // primaire URL
    val category: String = "",
    val source: String = "",
    val sourceRssIds: List<String> = emptyList(),  // verwijzingen naar RssItem.id
    val sourceUrls: List<String> = emptyList(),    // externe bronnen
    val topics: List<String> = emptyList(),
    val feedReason: String = "",
    val isRead: Boolean = false,
    val starred: Boolean = false,
    val liked: Boolean? = null,
    val createdAt: String,
    val publishedDate: String? = null
)
