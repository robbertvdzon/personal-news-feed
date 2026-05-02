package com.vdzon.newsfeedbackend.service

import com.rometools.rome.io.SyndFeedInput
import com.rometools.rome.io.XmlReader
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import java.net.URI
import java.time.Instant
import java.time.ZoneOffset
import java.time.temporal.ChronoUnit

data class RawArticle(
    val title: String,
    val url: String,
    val description: String,
    val source: String,
    val publishedAt: Instant
)

@Service
class RssFeedService {

    private val log = LoggerFactory.getLogger(RssFeedService::class.java)

    private val feedsPerCategory = mapOf(
        "kotlin" to listOf(
            "https://blog.jetbrains.com/kotlin/feed/",
            "https://developer.android.com/feeds/androidx-release-notes.xml"
        ),
        "flutter" to listOf(
            "https://medium.com/feed/flutter",
            "https://medium.com/feed/dartlang"
        ),
        "ai" to listOf(
            "https://blogs.microsoft.com/ai/feed/",
            "https://www.deepmind.com/blog/rss.xml",
            "https://huggingface.co/blog/feed.xml"
        ),
        "blockchain" to listOf(
            "https://cointelegraph.com/rss",
            "https://decrypt.co/feed"
        ),
        "spring" to listOf(
            "https://spring.io/blog.atom",
            "https://feeds.feedburner.com/baeldung"
        ),
        "web_dev" to listOf(
            "https://css-tricks.com/feed/",
            "https://dev.to/feed/tag/webdev",
            "https://developer.chrome.com/static/blog/feed.xml"
        ),
        "overig" to listOf(
            "https://news.ycombinator.com/rss",
            "https://www.theregister.com/software/developer/headlines.atom"
        )
    )

    private val generalFeeds = listOf(
        "https://news.ycombinator.com/rss",
        "https://dev.to/feed",
        "https://www.theregister.com/headlines.atom",
        "https://feeds.bbci.co.uk/news/rss.xml",
        "https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml",
        "https://feeds.feedburner.com/TheHackersNews"
    )

    fun fetchForCategory(category: String, maxAgeDays: Long = 7): List<RawArticle> {
        val feeds = feedsPerCategory[category] ?: generalFeeds
        val cutoff = Instant.now().minus(maxAgeDays, ChronoUnit.DAYS)
        return feeds.flatMap { url -> fetchFeed(url, cutoff) }
            .distinctBy { it.url }
            .sortedByDescending { it.publishedAt }
            .take(50)
    }

    fun fetchAll(maxAgeDays: Long = 3): List<RawArticle> {
        val cutoff = Instant.now().minus(maxAgeDays, ChronoUnit.DAYS)
        return (feedsPerCategory.values.flatten() + generalFeeds)
            .distinct()
            .flatMap { url -> fetchFeed(url, cutoff) }
            .distinctBy { it.url }
            .sortedByDescending { it.publishedAt }
    }

    private fun fetchFeed(url: String, cutoff: Instant): List<RawArticle> {
        return try {
            val connection = URI(url).toURL().openConnection().apply {
                connectTimeout = 5000
                readTimeout = 8000
                setRequestProperty("User-Agent", "PersonalNewsFeed/1.0")
            }
            val feed = SyndFeedInput().build(XmlReader(connection.getInputStream()))
            feed.entries.mapNotNull { entry ->
                val published = entry.publishedDate?.toInstant()
                    ?: entry.updatedDate?.toInstant()
                    ?: Instant.now()
                if (published.isBefore(cutoff)) return@mapNotNull null
                RawArticle(
                    title = entry.title?.trim() ?: return@mapNotNull null,
                    url = entry.link?.trim() ?: return@mapNotNull null,
                    description = (entry.description?.value ?: entry.contents.firstOrNull()?.value ?: "")
                        .replace(Regex("<[^>]+>"), "")
                        .take(800)
                        .trim(),
                    source = feed.title?.trim() ?: URI(url).host,
                    publishedAt = published
                )
            }
        } catch (e: Exception) {
            log.warn("RSS feed ophalen mislukt [{}]: {}", url, e.message)
            emptyList()
        }
    }
}
