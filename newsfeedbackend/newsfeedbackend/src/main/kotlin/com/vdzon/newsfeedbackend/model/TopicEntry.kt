package com.vdzon.newsfeedbackend.model

/**
 * Eén onderwerp in de topic-geschiedenis van een gebruiker.
 * Houdt bij hoe vaak en wanneer een onderwerp in nieuws en podcasts is voorbijgekomen,
 * en hoeveel interesse de gebruiker erin heeft getoond (likes, ster).
 */
data class TopicEntry(
    val topic: String,
    val firstSeen: String = java.time.Instant.now().toString(),

    /** Laatste keer dat dit onderwerp in een nieuwsartikel voorkwam */
    val lastSeenNews: String? = null,
    /** Laatste keer dat dit onderwerp in een podcast werd besproken */
    val lastSeenPodcast: String? = null,

    /** Aantal nieuwsartikelen met dit onderwerp */
    val newsCount: Int = 0,
    /** Aantal keren dat het onderwerp in een podcast werd aangestipt */
    val podcastMentionCount: Int = 0,
    /** Aantal keren dat het onderwerp diepgaand in een podcast werd behandeld */
    val podcastDeepCount: Int = 0,

    /** Aantal keren dat de gebruiker een artikel over dit onderwerp heeft geliked */
    val likedCount: Int = 0,
    /** Aantal keren dat de gebruiker een artikel over dit onderwerp heeft opgeslagen */
    val starredCount: Int = 0,
)
