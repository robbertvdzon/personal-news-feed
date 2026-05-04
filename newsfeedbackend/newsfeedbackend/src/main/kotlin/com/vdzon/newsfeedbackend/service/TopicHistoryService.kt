package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.NewsItem
import com.vdzon.newsfeedbackend.model.TopicEntry
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import java.time.Duration
import java.time.Instant

/**
 * Beheert de topic-geschiedenis per gebruiker:
 * - welke onderwerpen zijn eerder in nieuws / podcasts voorbijgekomen?
 * - hoe diep zijn ze behandeld?
 * - hoeveel interesse toont de gebruiker (likes, sterren)?
 *
 * Biedt context-strings voor de Anthropic-prompts zodat Claude betere,
 * gevarieerder keuzes maakt bij nieuwsselectie en podcast-generatie.
 */
@Service
class TopicHistoryService(
    private val storageService: StorageService,
    private val anthropicService: AnthropicService
) {
    private val log = LoggerFactory.getLogger(TopicHistoryService::class.java)

    // ── Topic-extractie na nieuws-refresh ─────────────────────────────────────

    /**
     * Extraheert topics uit de opgegeven nieuwsartikelen (via Claude),
     * slaat ze op in de items zelf én werkt de topic-geschiedenis bij.
     * Geeft de bijgewerkte items terug (met gevuld topics-veld).
     */
    fun extractAndUpdateFromNewsItems(username: String, items: List<NewsItem>): List<NewsItem> {
        val relevantItems = items.filter { !it.isSummary && it.topics.isEmpty() }
        if (relevantItems.isEmpty()) return items

        val existingTopics = storageService.loadTopicHistory(username).map { it.topic }

        return try {
            val (topicsPerItem, _) = anthropicService.extractNewsTopics(relevantItems, existingTopics)
            log.info("Topics geëxtraheerd voor {} artikelen voor {}", topicsPerItem.size, username)

            // Voeg topics toe aan de items
            val updatedItems = items.map { item ->
                val topics = topicsPerItem[item.id]
                if (topics != null && topics.isNotEmpty()) item.copy(topics = topics) else item
            }

            // Werk de topic-geschiedenis bij
            mergeNewsTopics(username, updatedItems.filter { it.topics.isNotEmpty() })

            updatedItems
        } catch (e: Exception) {
            log.error("Topic-extractie mislukt voor {}: {}", username, e.message)
            items  // geef originele items terug als fallback
        }
    }

    // ── Topic-update na podcast ────────────────────────────────────────────────

    /**
     * Werkt de topic-geschiedenis bij na het genereren van een podcast.
     * [topics] = alle geëxtraheerde onderwerpen.
     * [deepTopics] = de eerste helft (de meest uitgebreid behandelde onderwerpen).
     */
    fun mergePodcastTopics(username: String, topics: List<String>, deepTopics: List<String> = emptyList()) {
        if (topics.isEmpty()) return
        val entries = storageService.loadTopicHistory(username).toMutableList()
        val now = Instant.now().toString()

        topics.forEach { topic ->
            val isDeep = deepTopics.any { it.equals(topic, ignoreCase = true) }
            val existing = findExisting(entries, topic)
            if (existing != null) {
                val idx = entries.indexOf(existing)
                entries[idx] = existing.copy(
                    lastSeenPodcast = now,
                    podcastMentionCount = existing.podcastMentionCount + 1,
                    podcastDeepCount = if (isDeep) existing.podcastDeepCount + 1 else existing.podcastDeepCount
                )
            } else {
                entries.add(TopicEntry(
                    topic = topic,
                    firstSeen = now,
                    lastSeenPodcast = now,
                    podcastMentionCount = 1,
                    podcastDeepCount = if (isDeep) 1 else 0
                ))
            }
        }

        storageService.saveTopicHistory(username, entries)
        log.info("Podcast topics bijgewerkt voor {}: {} onderwerpen ({} diep)", username, topics.size, deepTopics.size)
    }

    // ── Feedback-updates ──────────────────────────────────────────────────────

    /** Verwerk een like of dislike op een artikel. */
    fun onFeedback(username: String, item: NewsItem, liked: Boolean?) {
        if (liked != true || item.topics.isEmpty()) return
        val entries = storageService.loadTopicHistory(username).toMutableList()
        item.topics.forEach { topic ->
            val existing = findExisting(entries, topic)
            if (existing != null) {
                val idx = entries.indexOf(existing)
                entries[idx] = existing.copy(likedCount = existing.likedCount + 1)
            }
            // Geen nieuwe entry aanmaken voor likes alleen — topic moet al bekend zijn
        }
        storageService.saveTopicHistory(username, entries)
    }

    /** Verwerk het opslaan (ster) van een artikel. */
    fun onStarred(username: String, item: NewsItem, nowStarred: Boolean) {
        if (item.topics.isEmpty()) return
        val entries = storageService.loadTopicHistory(username).toMutableList()
        val delta = if (nowStarred) 1 else -1
        item.topics.forEach { topic ->
            val existing = findExisting(entries, topic)
            if (existing != null) {
                val idx = entries.indexOf(existing)
                entries[idx] = existing.copy(starredCount = (existing.starredCount + delta).coerceAtLeast(0))
            }
        }
        storageService.saveTopicHistory(username, entries)
    }

    // ── Context-strings voor prompts ──────────────────────────────────────────

    /**
     * Bouwt een context-string voor gebruik in de nieuws-selectie prompt.
     * Helpt Claude beslissen of een artikel écht nieuw is of herhaling.
     */
    fun buildNewsContext(username: String): String {
        val entries = storageService.loadTopicHistory(username)
        if (entries.isEmpty()) return ""

        val now = Instant.now()
        val sorted = entries.sortedByDescending { lastSeenInstant(it) }.take(50)

        val lines = sorted.map { entry -> formatForNews(entry, now) }

        return """
Topic-geschiedenis — gebruik dit om te beoordelen of een artikel écht nieuwe informatie bevat:

${lines.joinToString("\n")}

Richtlijnen voor artikelselectie:
- NIEUW onderwerp (staat niet in de lijst): altijd tonen als relevant
- Recent onderwerp (<14 dagen geleden, 3+ keer gezien): ALLEEN tonen bij aantoonbaar nieuwe ontwikkeling (nieuwe release, grote update, incident, nieuw onderzoek)
- Matig recent (14-42 dagen geleden): tonen als relevant
- Oud onderwerp (>42 dagen geleden): vrijelijk tonen
- Onderwerpen met hoge liked/opgeslagen-score zijn hoge interesse — prioriteer nieuwe content hierop
        """.trimIndent()
    }

    /**
     * Bouwt een context-string voor gebruik in de podcast-generatie prompt.
     * Helpt Claude afwisseling te bewaken tussen afleveringen.
     */
    fun buildPodcastContext(username: String): String {
        val entries = storageService.loadTopicHistory(username)
        if (entries.isEmpty()) return ""

        val now = Instant.now()

        val recentPodcast = entries
            .filter { it.lastSeenPodcast != null }
            .sortedByDescending { Instant.parse(it.lastSeenPodcast!!) }
            .take(12)

        val userInterests = entries
            .filter { it.likedCount + it.starredCount > 0 }
            .sortedByDescending { it.likedCount * 2 + it.starredCount * 3 }
            .take(8)

        val freshCandidates = entries
            .filter {
                it.newsCount > 0 &&
                (it.lastSeenPodcast == null ||
                 Duration.between(Instant.parse(it.lastSeenPodcast!!), now).toDays() > 21)
            }
            .sortedByDescending { it.newsCount + it.likedCount * 2 + it.starredCount * 3 }
            .take(10)

        val sb = StringBuilder("Onderwerp-geschiedenis voor de podcast:\n")

        if (recentPodcast.isNotEmpty()) {
            sb.appendLine("\nRecent in de podcast besproken (vermijd als hoofdonderwerp tenzij grote nieuwe ontwikkeling):")
            recentPodcast.forEach { entry ->
                val days = Duration.between(Instant.parse(entry.lastSeenPodcast!!), now).toDays()
                val depth = if (entry.podcastDeepCount > 0) "diepgaand" else "aangestipt"
                sb.appendLine("- \"${entry.topic}\" ($days dagen geleden, $depth)")
            }
        }

        if (userInterests.isNotEmpty()) {
            sb.appendLine("\nInteressegebieden van de gebruiker (hoge prioriteit):")
            userInterests.forEach { entry ->
                val parts = mutableListOf<String>()
                if (entry.likedCount > 0) parts.add("${entry.likedCount}× geliked")
                if (entry.starredCount > 0) parts.add("${entry.starredCount}× opgeslagen")
                sb.appendLine("- \"${entry.topic}\" (${parts.joinToString(", ")})")
            }
        }

        if (freshCandidates.isNotEmpty()) {
            sb.appendLine("\nGeschikt voor (diepere) behandeling — lang niet of nooit in podcast:")
            freshCandidates.forEach { entry ->
                val lastPodcast = entry.lastSeenPodcast
                    ?.let { "${Duration.between(Instant.parse(it), now).toDays()} dagen geleden" }
                    ?: "nog nooit"
                sb.appendLine("- \"${entry.topic}\" (podcast: $lastPodcast, ${entry.newsCount}× in nieuws)")
            }
        }

        sb.appendLine("""
Richtlijnen voor onderwerpkeuze:
- Vermijd onderwerpen die <14 dagen geleden diepgaand zijn behandeld, tenzij er een grote nieuwe ontwikkeling is
- Prioriteer onderwerpen die de gebruiker heeft geliked of opgeslagen
- Varieer: kies bij voorkeur onderwerpen die al langer niet in de podcast zijn geweest
- Mag eerder behandelde onderwerpen aanstippen, maar ga er pas weer diep op in na minimaal 2-3 weken""".trimIndent())

        return sb.toString()
    }

    // ── Interne helpers ───────────────────────────────────────────────────────

    private fun mergeNewsTopics(username: String, items: List<NewsItem>) {
        val entries = storageService.loadTopicHistory(username).toMutableList()
        val now = Instant.now().toString()

        items.forEach { item ->
            item.topics.forEach { topic ->
                val existing = findExisting(entries, topic)
                if (existing != null) {
                    val idx = entries.indexOf(existing)
                    entries[idx] = existing.copy(
                        lastSeenNews = now,
                        newsCount = existing.newsCount + 1
                    )
                } else {
                    entries.add(TopicEntry(
                        topic = topic,
                        firstSeen = now,
                        lastSeenNews = now,
                        newsCount = 1
                    ))
                }
            }
        }

        storageService.saveTopicHistory(username, entries)
    }

    /**
     * Zoekt een bestaande entry die "nauw verwant" is aan [newTopic].
     * Gebruikt case-insensitieve vergelijking en substring-matching.
     */
    private fun findExisting(entries: List<TopicEntry>, newTopic: String): TopicEntry? {
        val lcNew = newTopic.lowercase().trim()
        return entries.firstOrNull { entry ->
            val lcExisting = entry.topic.lowercase().trim()
            lcExisting == lcNew ||
            lcExisting.contains(lcNew) ||
            lcNew.contains(lcExisting)
        }
    }

    private fun lastSeenInstant(entry: TopicEntry): Instant {
        val news = entry.lastSeenNews?.let { runCatching { Instant.parse(it) }.getOrNull() }
        val podcast = entry.lastSeenPodcast?.let { runCatching { Instant.parse(it) }.getOrNull() }
        return maxOfOrNull(listOfNotNull(news, podcast)) ?: Instant.EPOCH
    }

    private fun maxOfOrNull(instants: List<Instant>): Instant? =
        instants.maxByOrNull { it.epochSecond }

    private fun formatForNews(entry: TopicEntry, now: Instant): String {
        val parts = mutableListOf<String>()
        entry.lastSeenNews?.let {
            val days = Duration.between(Instant.parse(it), now).toDays()
            parts.add("nieuws: ${days}d geleden, ${entry.newsCount}×")
        }
        entry.lastSeenPodcast?.let {
            val days = Duration.between(Instant.parse(it), now).toDays()
            val depth = if (entry.podcastDeepCount > 0) "diepgaand" else "aangestipt"
            parts.add("podcast: ${days}d geleden, $depth")
        }
        if (entry.likedCount > 0) parts.add("${entry.likedCount}× geliked")
        if (entry.starredCount > 0) parts.add("${entry.starredCount}× opgeslagen")
        return "- \"${entry.topic}\" (${parts.joinToString(", ")})"
    }
}
