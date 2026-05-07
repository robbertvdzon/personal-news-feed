package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.FeedItem
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
    private val feedItemService: FeedItemService,
    private val rssFetchService: RssFetchService,
    private val anthropicService: AnthropicService,
    private val settingsService: SettingsService,
    private val topicHistoryService: TopicHistoryService
) {
    private val log = LoggerFactory.getLogger(RssProcessingService::class.java)
    private val runningUsers = ConcurrentHashMap<String, AtomicBoolean>()

    /** Verwerkt elk uur automatisch alle RSS-feeds voor alle gebruikers (op het hele uur: 12:00, 13:00, ...). */
    @Scheduled(cron = "0 0 * * * *")
    fun scheduledProcessAllUsers() {
        log.info("Uurlijkse RSS-verwerking gestart")
        val startMs = System.currentTimeMillis()
        val usernames = storageService.getAllUsernames()
        for (username in usernames) {
            try {
                processUser(username)
            } catch (e: Exception) {
                log.error("RSS-verwerking mislukt voor {}: {}", username, e.message)
            }
        }
        val elapsedSeconds = (System.currentTimeMillis() - startMs) / 1000
        log.info("Uurlijkse RSS-verwerking klaar voor {} gebruiker(s) in {}s", usernames.size, elapsedSeconds)
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
        val doProcessStartMs = System.currentTimeMillis()
        log.info("RSS-verwerking gestart voor {}", username)
        val rssUrls = storageService.loadRssFeeds(username).feeds
        if (rssUrls.isEmpty()) {
            log.info("Geen RSS-feeds geconfigureerd voor {}", username)
            return 0
        }

        val categories = settingsService.getSettings(username)
        val enabledCategories = categories.filter { it.enabled && !it.isSystem }

        // Stap 1: Haal alle RSS-items op (max 4 dagen oud)
        val fetched = rssFetchService.fetchAll(rssUrls, maxAgeDays = 4)
        log.info("RSS: {} artikelen opgehaald voor {} (max 4 dagen oud)", fetched.size, username)

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
        val total = newRaw.size

        for ((idx, raw) in newRaw.withIndex()) {
            val progress = "${idx + 1}/$total"
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
                log.info("({}) Samenvatting klaar: '{}' → categorie '{}'",
                    progress, summary.title.take(50), summary.category)
            } catch (e: Exception) {
                log.warn("({}) Samenvatting mislukt voor '{}': {}", progress, raw.title, e.message)
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

                    // Stap 5: Maak FeedItems voor geselecteerde RSS-items
                    val selectedRssItems = updatedItems.filter { it.inFeed }
                    if (selectedRssItems.isNotEmpty()) {
                        try {
                            val feedItemsToAdd = mutableListOf<FeedItem>()
                            val rssItemsWithFeedId = mutableListOf<RssItem>()
                            val totalSelected = selectedRssItems.size

                            for ((idx, rssItem) in selectedRssItems.withIndex()) {
                                val progress = "${idx + 1}/$totalSelected"
                                try {
                                    val (richSummary, feedItemCost) = anthropicService.generateFeedItemSummary(rssItem, enabledCategories)
                                    totalCost += feedItemCost
                                    val feedItemId = UUID.randomUUID().toString()
                                    val feedItem = FeedItem(
                                        id = feedItemId,
                                        title = rssItem.title,
                                        summary = richSummary,
                                        url = rssItem.url,
                                        category = rssItem.category,
                                        source = rssItem.source,
                                        sourceRssIds = listOf(rssItem.id),
                                        sourceUrls = listOf(rssItem.url),
                                        topics = rssItem.topics,
                                        feedReason = rssItem.feedReason,
                                        createdAt = Instant.now().toString(),
                                        publishedDate = rssItem.publishedDate
                                    )
                                    feedItemsToAdd.add(feedItem)
                                    rssItemsWithFeedId.add(rssItem.copy(feedItemId = feedItemId))
                                    log.info("({}) FeedItem aangemaakt: '{}' → '{}'",
                                        progress, rssItem.title.take(50), rssItem.category)
                                } catch (e: Exception) {
                                    log.warn("({}) FeedItem samenvatting mislukt voor '{}': {}", progress, rssItem.title, e.message)
                                    // Fallback: gebruik rssItem.summary als samenvatting
                                    val feedItemId = UUID.randomUUID().toString()
                                    val feedItem = FeedItem(
                                        id = feedItemId,
                                        title = rssItem.title,
                                        summary = rssItem.summary,
                                        url = rssItem.url,
                                        category = rssItem.category,
                                        source = rssItem.source,
                                        sourceRssIds = listOf(rssItem.id),
                                        sourceUrls = listOf(rssItem.url),
                                        topics = rssItem.topics,
                                        feedReason = rssItem.feedReason,
                                        createdAt = Instant.now().toString(),
                                        publishedDate = rssItem.publishedDate
                                    )
                                    feedItemsToAdd.add(feedItem)
                                    rssItemsWithFeedId.add(rssItem.copy(feedItemId = feedItemId))
                                }
                            }

                            feedItemService.addItems(username, feedItemsToAdd)
                            rssItemService.updateItems(username, rssItemsWithFeedId)
                            log.info("{} FeedItems aangemaakt voor {}", feedItemsToAdd.size, username)
                        } catch (e: Exception) {
                            log.error("FeedItem aanmaak mislukt voor {}: {}", username, e.message)
                        }
                    }
                }
            } catch (e: Exception) {
                log.error("Feed-selectie mislukt voor {}: {}", username, e.message)
            }
        }

        // Stap 7: Werk topic-geschiedenis bij
        if (summarized.any { it.topics.isNotEmpty() }) {
            topicHistoryService.mergeRssItemTopics(username, summarized)
        }

        val doProcessElapsed = (System.currentTimeMillis() - doProcessStartMs) / 1000
        log.info("RSS-verwerking klaar voor {}: {} nieuwe items, kosten \${}, duur {}s", username, summarized.size, "%.4f".format(totalCost), doProcessElapsed)
        return summarized.size
    }
}
