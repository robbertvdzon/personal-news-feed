package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.RssItem
import org.slf4j.LoggerFactory
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Service
import java.time.Instant
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean

@Service
class RssProcessingService(
    private val storageService: StorageService,
    private val rssItemService: RssItemService,
    private val rssFetchService: RssFetchService,
    private val anthropicService: AnthropicService,
    private val settingsService: SettingsService,
    private val topicHistoryService: TopicHistoryService
) {
    private val log = LoggerFactory.getLogger(RssProcessingService::class.java)
    private val runningUsers = ConcurrentHashMap<String, AtomicBoolean>()

    /** Verwerkt elk uur automatisch alle RSS-feeds voor alle gebruikers. */
    @Scheduled(fixedDelay = 3_600_000, initialDelay = 60_000)
    fun scheduledProcessAllUsers() {
        log.info("Geplande RSS-verwerking gestart")
        val usernames = storageService.getAllUsernames()
        for (username in usernames) {
            try {
                processUser(username)
            } catch (e: Exception) {
                log.error("RSS-verwerking mislukt voor {}: {}", username, e.message)
            }
        }
        log.info("Geplande RSS-verwerking klaar voor {} gebruiker(s)", usernames.size)
    }

    /**
     * Verwerkt RSS-feeds voor één gebruiker:
     * 1. Haal alle RSS-feeds op
     * 2. Sla nieuwe items op (nog niet samengevat)
     * 3. Maak AI-samenvatting + categorie per nieuw item
     * 4. Selecteer welke items in de feed moeten (batch AI-aanroep)
     * 5. Werk topic-geschiedenis bij
     *
     * Geeft het aantal nieuw verwerkte items terug.
     */
    fun processUser(username: String): Int {
        val lock = runningUsers.computeIfAbsent(username) { AtomicBoolean(false) }
        if (!lock.compareAndSet(false, true)) {
            log.info("RSS-verwerking voor {} al bezig, overgeslagen", username)
            return 0
        }
        try {
            return doProcessUser(username)
        } finally {
            lock.set(false)
        }
    }

    private fun doProcessUser(username: String): Int {
        log.info("RSS-verwerking gestart voor {}", username)
        val rssUrls = storageService.loadRssFeeds(username).feeds
        if (rssUrls.isEmpty()) {
            log.info("Geen RSS-feeds geconfigureerd voor {}", username)
            return 0
        }

        val categories = settingsService.getSettings(username)
        val enabledCategories = categories.filter { it.enabled && !it.isSystem }

        // Stap 1: Haal alle RSS-items op
        val fetched = rssFetchService.fetchAll(rssUrls)
        log.info("RSS: {} artikelen opgehaald voor {}", fetched.size, username)

        // Stap 2: Filter al bekende URLs
        val existing = storageService.loadRssItems(username)
        val existingUrls = existing.map { it.url }.toSet()
        val newRaw = fetched.filter { it.url !in existingUrls }

        if (newRaw.isEmpty()) {
            log.info("Geen nieuwe RSS-items voor {}", username)
            return 0
        }
        log.info("{} nieuwe RSS-items gevonden voor {}", newRaw.size, username)

        // Stap 3: Samenvatten + categoriseren per item (individuele AI-aanroepen)
        val now = Instant.now().toString()
        val summarized = mutableListOf<RssItem>()
        var totalCost = 0.0

        for (raw in newRaw) {
            try {
                val (summary, cost) = anthropicService.summarizeRssItem(raw, enabledCategories)
                totalCost += cost
                val categoryId = enabledCategories
                    .find { it.name.equals(summary.category, ignoreCase = true) }
                    ?.id ?: summary.category.lowercase().replace(" ", "_")
                val item = RssItem(
                    id = UUID.randomUUID().toString(),
                    title = summary.title,
                    summary = summary.summary,
                    url = raw.url,
                    category = categoryId,
                    feedUrl = raw.feedUrl ?: "",
                    source = raw.source,
                    snippet = raw.snippet,
                    publishedDate = raw.publishedDate,
                    timestamp = now,
                    processedAt = now,
                    inFeed = false,
                    feedReason = "",
                    topics = summary.topics
                )
                summarized.add(item)
            } catch (e: Exception) {
                log.warn("Samenvatting mislukt voor '{}': {}", raw.title, e.message)
                // Item toch opslaan met snippet als samenvatting (zodat we het niet telkens opnieuw proberen)
                summarized.add(RssItem(
                    id = UUID.randomUUID().toString(),
                    title = raw.title,
                    summary = raw.snippet.take(500),
                    url = raw.url,
                    category = "",
                    feedUrl = raw.feedUrl ?: "",
                    source = raw.source,
                    snippet = raw.snippet,
                    publishedDate = raw.publishedDate,
                    timestamp = now,
                    processedAt = now
                ))
            }
        }

        // Sla alle nieuwe items op (zonder inFeed nog)
        rssItemService.addItems(username, summarized)

        // Stap 4: Batch feed-selectie — AI bepaalt welke items in de feed komen
        if (summarized.isNotEmpty()) {
            try {
                val existingFeedItems = existing.filter { it.inFeed }.takeLast(50)
                val likedTitles = rssItemService.getLikedItems(username).map { it.title }.take(20)
                val dislikedTitles = rssItemService.getDislikedItems(username).map { it.title }.take(20)
                val topicHistoryContext = topicHistoryService.buildNewsContext(username)

                val (selections, selCost) = anthropicService.selectFeedItems(
                    newItems = summarized,
                    existingFeedItems = existingFeedItems,
                    categories = enabledCategories,
                    likedTitles = likedTitles,
                    dislikedTitles = dislikedTitles,
                    topicHistoryContext = topicHistoryContext
                )
                totalCost += selCost

                if (selections.isNotEmpty()) {
                    val selectionByUrl = selections.associateBy { it.url }
                    val updatedItems = summarized.map { item ->
                        val sel = selectionByUrl[item.url]
                        if (sel != null) item.copy(inFeed = sel.inFeed, feedReason = sel.reason)
                        else item
                    }
                    rssItemService.updateItems(username, updatedItems)
                    val inFeedCount = updatedItems.count { it.inFeed }
                    log.info("Feed-selectie klaar voor {}: {}/{} items in feed", username, inFeedCount, updatedItems.size)
                }
            } catch (e: Exception) {
                log.error("Feed-selectie mislukt voor {}: {}", username, e.message)
            }
        }

        // Stap 5: Werk topic-geschiedenis bij
        if (summarized.any { it.topics.isNotEmpty() }) {
            topicHistoryService.mergeRssItemTopics(username, summarized)
        }

        log.info("RSS-verwerking klaar voor {}: {} nieuwe items, kosten \${}", username, summarized.size, "%.4f".format(totalCost))
        return summarized.size
    }
}
