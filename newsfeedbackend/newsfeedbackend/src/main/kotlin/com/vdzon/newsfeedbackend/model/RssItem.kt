package com.vdzon.newsfeedbackend.model

data class RssItem(
    val id: String,
    val title: String,
    val summary: String = "",
    val url: String,
    val category: String = "",
    val feedUrl: String = "",
    val source: String,
    val snippet: String = "",
    val publishedDate: String? = null,
    /** Tijdstip waarop dit item in de store is toegevoegd (ISO-8601) */
    val timestamp: String,
    /** Tijdstip waarop de AI-samenvatting is gegenereerd */
    val processedAt: String? = null,
    /** Staat dit item in de persoonlijke feed van de gebruiker? */
    val inFeed: Boolean = false,
    /** Reden waarom het item in de feed staat (AI-verklaring) */
    val feedReason: String = "",
    val isRead: Boolean = false,
    val starred: Boolean = false,
    val liked: Boolean? = null,
    val topics: List<String> = emptyList(),
    val feedItemId: String? = null
)
