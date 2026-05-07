package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.CategorySettings
import com.vdzon.newsfeedbackend.model.FeedItem
import com.vdzon.newsfeedbackend.model.NewsItem
import com.vdzon.newsfeedbackend.model.RssItem
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.http.client.SimpleClientHttpRequestFactory
import org.springframework.stereotype.Service
import org.springframework.web.client.RestClient
import tools.jackson.databind.ObjectMapper
import tools.jackson.module.kotlin.readValue
import java.time.Instant
import java.time.LocalDate
import java.util.UUID
import java.util.concurrent.Semaphore

data class SummarizedArticle(
    val title: String,
    val summary: String,
    val url: String,
    val source: String,
    val feedUrl: String? = null
)

data class ClaudeSearchResult(
    val articles: List<SummarizedArticle>,
    val costUsd: Double
)

@Service
class AnthropicService(
    private val objectMapper: ObjectMapper,
    @Value("\${app.anthropic.api-key}") private val apiKey: String,
    @Value("\${app.anthropic.summary-model}") private val summaryModel: String,
    @Value("\${app.anthropic.base-url}") private val baseUrl: String
) {
    private val log = LoggerFactory.getLogger(AnthropicService::class.java)
    private val semaphore = Semaphore(3)

    private val client: RestClient by lazy {
        val factory = SimpleClientHttpRequestFactory().apply {
            setConnectTimeout(10_000)
            setReadTimeout(120_000)
        }
        RestClient.builder()
            .requestFactory(factory)
            .baseUrl(baseUrl)
            .defaultHeader("x-api-key", apiKey)
            .defaultHeader("anthropic-version", "2023-06-01")
            .defaultHeader("content-type", "application/json")
            .build()
    }

    // Fase 2: selecteert de beste artikelen op basis van titels + snippets + feedback + topic-geschiedenis
    fun selectArticles(
        articles: List<TavilySearchResult>,
        categoryName: String,
        extraInstructions: String,
        preferredCount: Int,
        maxCount: Int,
        likedTitles: List<String> = emptyList(),
        dislikedTitles: List<String> = emptyList(),
        topicHistoryContext: String = ""
    ): Pair<List<Int>, Double> {
        if (articles.isEmpty()) return Pair(emptyList(), 0.0)

        val instructionsPart = if (extraInstructions.isNotBlank())
            "\n\nUser's specific interests:\n$extraInstructions"
        else ""

        val likedPart = if (likedTitles.isNotEmpty())
            "\n\nUser liked these articles (select similar ones):\n" +
                    likedTitles.take(10).joinToString("\n") { "- \"$it\"" }
        else ""

        val dislikedPart = if (dislikedTitles.isNotEmpty())
            "\n\nUser disliked these articles (avoid similar ones):\n" +
                    dislikedTitles.take(10).joinToString("\n") { "- \"$it\"" }
        else ""

        val topicHistoryPart = if (topicHistoryContext.isNotBlank())
            "\n\n$topicHistoryContext"
        else ""

        val today = LocalDate.now()
        val articleList = articles.mapIndexed { i, a ->
            val datePart = if (a.publishedDate != null) "\n   Published: ${a.publishedDate}" else ""
            "${i + 1}. Title: \"${a.title}\"$datePart\n   Snippet: ${a.snippet.take(500)}"
        }.joinToString("\n\n")

        val prompt = """
            You are a news curator. Select the $preferredCount to $maxCount most relevant articles for the user.
            Today's date is: $today

            Category: $categoryName$instructionsPart$likedPart$dislikedPart$topicHistoryPart

            Articles to evaluate:
            $articleList

            Rules:
            - Select between $preferredCount and $maxCount articles
            - Prefer articles that match the user's specific interests and liked examples
            - Avoid articles similar to disliked examples
            - Apply the topic history guidelines above when judging articles on familiar topics
            - Avoid duplicate topics within this selection
            - IMPORTANT: If an article has a published date, prefer articles from the last 3 days. Reject articles older than 14 days unless they are highly relevant and no recent alternatives exist.
            - Return ONLY a JSON object, no explanation:
            {"selected": [1, 3, 5]}
            (use 1-based article numbers)
        """.trimIndent()

        val (text, cost) = callWithRetry(prompt, summaryModel)
        return try {
            val json = extractJsonObject(text)
            val root = objectMapper.readTree(json)
            val selectedArray = root.path("selected")
            val indices = mutableListOf<Int>()
            for (i in 0 until selectedArray.size()) {
                val num = selectedArray.get(i).asInt(0)
                if (num >= 1 && num <= articles.size) {
                    indices.add(num - 1)  // 0-based
                }
            }
            log.info("Selectie voor '{}': {}/{} artikelen gekozen", categoryName, indices.size, articles.size)
            Pair(indices.take(maxCount), cost)
        } catch (e: Exception) {
            log.error("Selectie parsen mislukt: {}", e.message)
            // fallback: gewoon de eerste preferredCount
            Pair((0 until minOf(preferredCount, articles.size)).toList(), cost)
        }
    }

    // Stelt geschikte nieuwswebsites voor voor een categorie
    fun suggestWebsites(categoryName: String, extraInstructions: String): List<String> {
        val instructionsPart = if (extraInstructions.isNotBlank())
            "\n\nAdditional context: $extraInstructions"
        else ""

        val prompt = """
            Suggest 8 to 12 reliable English-language news websites for the category: "$categoryName"$instructionsPart

            Rules:
            - Return ONLY a JSON array of domain names, no explanation
            - Only the domain (e.g. "blog.jetbrains.com", not full URLs)
            - Prefer sites that publish frequently and have good technical depth
            - Mix of official blogs, independent publications and aggregators
            - Example output: ["blog.example.com", "otherdomain.io"]
        """.trimIndent()

        val (text, _) = callWithRetry(prompt, summaryModel)
        return try {
            val json = text.let {
                val start = it.indexOf('[')
                val end = it.lastIndexOf(']')
                if (start != -1 && end != -1) it.substring(start, end + 1) else "[]"
            }
            val root = objectMapper.readTree(json)
            val domains = mutableListOf<String>()
            for (i in 0 until root.size()) {
                val domain = root.get(i).asText("").trim()
                if (domain.isNotBlank()) domains.add(domain)
            }
            log.info("Website-suggesties voor '{}': {}", categoryName, domains)
            domains
        } catch (e: Exception) {
            log.error("Website-suggesties parsen mislukt: {}", e.message)
            emptyList()
        }
    }

    // Genereert een goede Engelse zoekquery voor Tavily op basis van categorie + extra instructies + feedback
    fun generateSearchQuery(
        categoryName: String,
        extraInstructions: String,
        likedTitles: List<String> = emptyList(),
        dislikedTitles: List<String> = emptyList()
    ): String {
        val instructionsPart = if (extraInstructions.isNotBlank())
            "\n\nAdditional context about what the user is interested in:\n$extraInstructions"
        else ""

        val likedPart = if (likedTitles.isNotEmpty())
            "\n\nUser liked these articles recently (find more like these):\n" +
                    likedTitles.take(10).joinToString("\n") { "- \"$it\"" }
        else ""

        val dislikedPart = if (dislikedTitles.isNotEmpty())
            "\n\nUser disliked these articles recently (avoid similar content):\n" +
                    dislikedTitles.take(10).joinToString("\n") { "- \"$it\"" }
        else ""

        val prompt = """
            You are a search query expert. Generate a concise and effective English search query for recent news articles.

            Category: $categoryName$instructionsPart$likedPart$dislikedPart

            Rules:
            - Write ONLY the search query, nothing else — no explanation, no quotes
            - In English
            - 4-8 words
            - Target specific recent EVENTS, STORIES or DEVELOPMENTS — NOT news websites, aggregators or platforms about the topic
            - Bad example for "positive news": "positive news websites today" → finds news aggregator sites
            - Good example for "positive news": "inspiring breakthroughs human achievement 2025" → finds actual stories
            - Focus on what is HAPPENING, not on media COVERING the topic
        """.trimIndent()

        val (text, _) = callWithRetry(prompt, summaryModel)
        val query = text.trim().removeSurrounding("\"")
        log.info("Gegenereerde zoekquery voor '{}': '{}'", categoryName, query)
        return query.ifBlank { "$categoryName news" }
    }

    // Extraheert de besproken onderwerpen uit een podcast-script
    fun extractPodcastTopics(scriptText: String): Pair<List<String>, Double> {
        val prompt = """
            Analyseer het volgende podcast-script en geef een lijst van de besproken onderwerpen.

            Script:
            ${scriptText.take(8000)}

            Regels:
            - Geef 5 tot 10 concrete onderwerpen die daadwerkelijk besproken zijn
            - Elk onderwerp is 2 tot 6 woorden
            - In het Nederlands
            - Retourneer ALLEEN een JSON-array, geen uitleg:
            ["Onderwerp 1", "Onderwerp 2", "Onderwerp 3"]
        """.trimIndent()

        val (text, cost) = callWithRetry(prompt, summaryModel)
        return try {
            val start = text.indexOf('[')
            val end = text.lastIndexOf(']')
            val json = if (start != -1 && end != -1) text.substring(start, end + 1) else "[]"
            val root = objectMapper.readTree(json)
            val topics = (0 until root.size()).map { root.get(it).asText("") }.filter { it.isNotBlank() }
            log.info("Podcast onderwerpen geëxtraheerd: {}", topics)
            Pair(topics, cost)
        } catch (e: Exception) {
            log.error("Podcast onderwerpen parsen mislukt: {}", e.message)
            Pair(emptyList(), cost)
        }
    }

    // Schrijft een Nederlandstalig podcast-interview-script
    // Analyseert ruwe RSS-artikelen en bepaalt de beste podcast-onderwerpen
    fun determinePodcastTopics(
        rssArticles: List<TavilySearchResult>,
        likedTitles: List<String> = emptyList(),
        dislikedTitles: List<String> = emptyList(),
        starredTitles: List<String> = emptyList(),
        categoryInterests: List<String> = emptyList(),
        topicHistoryContext: String = "",
        periodDays: Int,
        durationMinutes: Int = 10
    ): Pair<String, Double> {
        val articleList = rssArticles.take(200).mapIndexed { i, a ->
            val datePart = if (a.publishedDate != null) " (${a.publishedDate})" else ""
            val snippet = a.snippet.take(1000).trim()
            if (snippet.isNotEmpty())
                "${i + 1}. [${a.source}]$datePart ${a.title}\n   $snippet"
            else
                "${i + 1}. [${a.source}]$datePart ${a.title}"
        }.joinToString("\n\n")

        val feedbackPart = buildString {
            if (likedTitles.isNotEmpty())
                append("\n\nInteressant gevonden door gebruiker:\n${likedTitles.take(15).joinToString("\n") { "- $it" }}")
            if (dislikedTitles.isNotEmpty())
                append("\n\nNiet relevant gevonden door gebruiker:\n${dislikedTitles.take(10).joinToString("\n") { "- $it" }}")
            if (starredTitles.isNotEmpty())
                append("\n\nBewaard door gebruiker:\n${starredTitles.take(10).joinToString("\n") { "- $it" }}")
            if (categoryInterests.isNotEmpty())
                append("\n\nCategorieën waarvoor gebruiker interesse heeft: ${categoryInterests.joinToString(", ")}")
        }

        val historyPart = if (topicHistoryContext.isNotBlank()) "\n\n$topicHistoryContext" else ""

        // Schaal het aantal onderwerpen op basis van de podcastduur
        val mainTopics = when {
            durationMinutes <= 5  -> "1-2"
            durationMinutes <= 10 -> "2-3"
            durationMinutes <= 20 -> "3-4"
            durationMinutes <= 40 -> "4-5"
            else                  -> "5-6"
        }
        val newsItems = when {
            durationMinutes <= 5  -> "2-3"
            durationMinutes <= 10 -> "3-4"
            durationMinutes <= 20 -> "4-6"
            else                  -> "5-8"
        }

        val prompt = """
            Analyseer de volgende ${rssArticles.size} RSS-artikelen van de afgelopen $periodDays dag(en) en bepaal de beste onderwerpen voor een Nederlandstalige tech-podcast van $durationMinutes minuten.

            ARTIKELEN (titel en bron):
            $articleList
            $feedbackPart$historyPart

            Richtlijnen voor onderwerpkeuze:
            - Onderwerpen die in MEERDERE feeds terugkomen zijn "hot" — geef die voorrang
            - Houd rekening met de interesses en feedback van de gebruiker
            - Vermijd onderwerpen die recent al uitgebreid in de podcast zijn behandeld (zie geschiedenis)
            - Stem het aantal onderwerpen af op de duur: $durationMinutes minuten biedt ruimte voor $mainTopics hoofdonderwerpen

            Geef een gestructureerd redactioneel briefing-document met:
            - $mainTopics HOOFDONDERWERPEN: elk met een kernvraag, waarom het hot is, en interessante invalshoek
            - $newsItems NIEUWSITEMS: kort te noemen nieuwtjes (1-2 zinnen per stuk)

            Schrijf in het Nederlands. Geen extra uitleg, alleen het briefing-document.
        """.trimIndent()

        val (text, cost) = callWithRetry(prompt, summaryModel, maxTokens = 2000)
        log.info("Podcast onderwerpen bepaald: {} tekens, kosten \${}", text.length, "%.4f".format(cost))
        return Pair(text.trim(), cost)
    }

    fun generatePodcastScript(
        articles: List<NewsItem>,
        periodDays: Int,
        durationMinutes: Int,
        topicHistoryContext: String = "",
        customTopics: List<String> = emptyList(),
        topicPlan: String? = null,
        rssArticles: List<TavilySearchResult> = emptyList()
    ): Pair<String, Double> {
        val targetWords = durationMinutes * 140

        val previousTopicsPart = if (topicHistoryContext.isNotBlank())
            "\n\n$topicHistoryContext"
        else ""

        val prompt = if (customTopics.isNotEmpty()) {
            // Modus: gebruiker heeft eigen onderwerpen opgegeven
            val topicList = customTopics.joinToString("\n") { "- $it" }
            val contextPart = if (articles.isNotEmpty()) {
                val articleList = articles.take(20).mapIndexed { i, a ->
                    "${i + 1}. [${a.category}] ${a.title}\n   ${a.summary.take(300)}"
                }.joinToString("\n\n")
                "\n\nAchtergrond — recente artikelen die mogelijk relevant zijn:\n$articleList"
            } else ""

            """
                Schrijf een Nederlandstalig podcast-interview van circa $durationMinutes minuten (~$targetWords woorden)
                tussen een INTERVIEWER en een GAST (senior software developer).

                De gebruiker wil de volgende onderwerpen bespreken:
                $topicList

                Behandel elk onderwerp uitgebreid. Gebruik je kennis over de meest recente ontwikkelingen.
                Geef concrete voorbeelden, tools, frameworks of nieuws rondom deze onderwerpen.$contextPart$previousTopicsPart

                Richtlijnen:
                - Schrijf als een natuurlijk, vloeiend gesprek — geen stijve Q&A
                - Gebruik korte, duidelijke zinnen geschikt voor audio
                - INTERVIEWER introduceert onderwerpen en stelt vragen
                - GAST geeft diepgaande antwoorden vanuit een developer-perspectief
                - Vermijd moeilijk uit te spreken afkortingen; spreek ze uit (bv. "A I" niet "AI")
                - Verdeel de spreektijd ongeveer gelijk
                - Begin met een korte intro van de INTERVIEWER die de opgegeven onderwerpen aankondigt
                - Eindig met een samenvatting en afsluiting door de INTERVIEWER

                VERPLICHT FORMAAT — elke spreekbeurt op exact één regel:
                INTERVIEWER: [tekst]
                GAST: [tekst]

                Geen andere tekst, geen kopteksten, geen nummers, geen uitleg.
            """.trimIndent()
        } else if (topicPlan != null) {
            // Modus: twee-staps — gebruik vooraf bepaald topic-plan op basis van ruwe RSS
            val contextPart = if (rssArticles.isNotEmpty()) {
                val snippets = rssArticles.take(40).mapIndexed { i, a ->
                    "${i + 1}. [${a.source}] ${a.title}\n   ${a.snippet.take(200)}"
                }.joinToString("\n\n")
                "\n\nAchtergrond — relevante RSS-artikelen:\n$snippets"
            } else ""

            """
                Schrijf een Nederlandstalig podcast-interview van circa $durationMinutes minuten (~$targetWords woorden)
                tussen een INTERVIEWER en een GAST (senior software developer).

                Gebruik het volgende redactionele briefing-document als leidraad voor de inhoud:

                $topicPlan
                $contextPart$previousTopicsPart

                Richtlijnen:
                - Schrijf als een natuurlijk, vloeiend gesprek — geen stijve Q&A
                - Gebruik korte, duidelijke zinnen geschikt voor audio
                - INTERVIEWER introduceert onderwerpen en stelt vragen
                - GAST geeft diepgaande antwoorden vanuit een developer-perspectief
                - Vermijd moeilijk uit te spreken afkortingen; spreek ze uit (bv. "A I" niet "AI")
                - Verdeel de spreektijd ongeveer gelijk
                - Begin met een korte intro van de INTERVIEWER
                - Behandel elk hoofdonderwerp uitgebreid, nieuwsitems kort (1-2 zinnen)
                - Eindig met een samenvatting en afsluiting door de INTERVIEWER

                VERPLICHT FORMAAT — elke spreekbeurt op exact één regel:
                INTERVIEWER: [tekst]
                GAST: [tekst]

                Geen andere tekst, geen kopteksten, geen nummers, geen uitleg.
            """.trimIndent()
        } else {
            // Modus: gebaseerd op nieuwsartikelen van de afgelopen periode (legacy)
            val articleList = articles.take(30).mapIndexed { i, a ->
                "${i + 1}. [${a.category}] ${a.title}\n   ${a.summary.take(300)}"
            }.joinToString("\n\n")

            """
                Schrijf een Nederlandstalig podcast-interview van circa $durationMinutes minuten (~$targetWords woorden)
                tussen een INTERVIEWER en een GAST (senior software developer).

                Onderwerp: de laatste $periodDays dag(en) in software-ontwikkeling, AI en cloud.

                Gebaseerd op deze artikelen:
                $articleList$previousTopicsPart

                Richtlijnen:
                - Schrijf als een natuurlijk, vloeiend gesprek — geen stijve Q&A
                - Gebruik korte, duidelijke zinnen geschikt voor audio
                - INTERVIEWER introduceert onderwerpen en stelt vragen
                - GAST geeft diepgaande antwoorden vanuit een developer-perspectief
                - Vermijd moeilijk uit te spreken afkortingen; spreek ze uit (bv. "A I" niet "AI")
                - Verdeel de spreektijd ongeveer gelijk
                - Begin met een korte intro van de INTERVIEWER
                - Eindig met een samenvatting en afsluiting door de INTERVIEWER

                VERPLICHT FORMAAT — elke spreekbeurt op exact één regel:
                INTERVIEWER: [tekst]
                GAST: [tekst]

                Geen andere tekst, geen kopteksten, geen nummers, geen uitleg.
            """.trimIndent()
        }

        val (text, cost) = callWithRetry(prompt, summaryModel, maxTokens = 6000)
        val wordCount = text.split("\\s+".toRegex()).size
        log.info("Podcast script gegenereerd: {} woorden, kosten \${}", wordCount, "%.4f".format(cost))
        return Pair(text.trim(), cost)
    }

    // Genereert een dagelijkse samenvatting op basis van FeedItems en RSS-items
    fun generateDailySummaryFromRss(
        feedItems: List<FeedItem>,
        allRssItems: List<RssItem>,
        categories: List<CategorySettings>,
        likedTitles: List<String>,
        topicHistoryContext: String
    ): Pair<String, Double> {
        val categoryNames = categories.filter { it.enabled && !it.isSystem }.map { it.name }
        val feedList = feedItems.take(60).mapIndexed { i, item ->
            "${i+1}. [${item.category}] ${item.title}\n   ${item.summary.take(300)}"
        }.joinToString("\n\n")
        val allList = allRssItems.filter { !it.inFeed }.take(100).mapIndexed { i, item ->
            "${i+1}. [${item.category}] ${item.title} — ${item.summary.take(150)}"
        }.joinToString("\n")

        val today = LocalDate.now()
        val months = listOf("januari", "februari", "maart", "april", "mei", "juni",
            "juli", "augustus", "september", "oktober", "november", "december")
        val todayNl = "${today.dayOfMonth} ${months[today.monthValue - 1]} ${today.year}"

        val prompt = """
            Je bent een Nederlandse techredacteur die een dagelijkse ochtendsbriefing schrijft voor een programmeur.

            Schrijf een dagelijkse samenvatting op basis van het nieuws van de afgelopen 24 uur.

            Mijn interessegebieden: ${categoryNames.joinToString(", ")}
            Gelikete onderwerpen (schrijf hier meer over): ${likedTitles.joinToString(", ")}

            ## Feed-artikelen (geselecteerd als relevant):
            $feedList

            ## Overig RSS-nieuws (niet in feed, maar mogelijk interessant):
            $allList

            ## Topic-geschiedenis (recente trends):
            $topicHistoryContext

            Schrijf de samenvatting in het volgende formaat (gebruik echte Markdown headers):

            # Dagelijkse Samenvatting — $todayNl

            ## [Categorie naam 1]
            [Wat er nieuw is en wat de impact is voor een programmeur/liefhebber. 2-4 alinea's.]

            ## [Categorie naam 2]
            [...]

            ## Overig nieuws
            [Kort overzicht van andere nieuwswaardige items die niet in de interessegebieden vallen maar toch de moeite waard zijn. Maximaal 5 bullets of korte alinea's.]

            ## Trends
            [Alleen als er duidelijke patronen zijn: benoem kort 2-3 trends die je herkent in het nieuws van de afgelopen tijd. Sla dit onderdeel over als er geen duidelijke trends zijn.]

            Richtlijnen:
            - Schrijf in vloeiend journalistiek Nederlands
            - Focus op impact en betekenis voor een programmeur/tech-liefhebber
            - Noem geen artikelnummers of URLs
            - Herhaal geen oud nieuws tenzij er een betekenisvolle update is (geef dan kort aan wat er veranderd is)
            - De samenvatting mag 600-1000 woorden zijn
            - Geef ALLEEN de markdown tekst terug, geen uitleg of JSON wrapper
        """.trimIndent()

        val (text, cost) = callWithRetry(prompt, summaryModel)
        log.info("Dagelijkse samenvatting gegenereerd: {} tekens, kosten \${}", text.length, "%.4f".format(cost))
        return Pair(text.trim(), cost)
    }

    // Samenvatten van een artikel op basis van de volledige tekst (Tavily content)
    fun summarizeArticle(article: TavilyArticle, subject: String): Pair<SummarizedArticle, Double> {
        val prompt = """
            Je bent een Nederlandse tech-nieuwsredacteur.

            Schrijf een samenvatting van circa 400 woorden over het volgende artikel over "$subject".

            Titel: ${article.title}
            Bron: ${article.source}
            URL: ${article.url}

            Artikel tekst:
            ${article.content}

            Gebruik meerdere alinea's gescheiden door een lege regel.
            Schrijf de INHOUD — wat er is gebeurd, wat er is gezegd, wat de bevindingen zijn.
            Leg NIET uit wat het artikel behandelt. Geef gewoon de informatie zelf.
            Schrijf in het Nederlands.

            Geef je antwoord als ALLEEN een JSON object (geen uitleg, geen markdown):
            {
              "title": "Artikel titel",
              "summary": "Eerste alinea.\n\nTweede alinea.\n\nDerde alinea.",
              "url": "${article.url}",
              "source": "${article.source}"
            }
        """.trimIndent()

        val (text, cost) = callWithRetry(prompt, summaryModel)
        val json = extractJsonObject(text)
        return try {
            val result = objectMapper.readValue<SummarizedArticle>(json)
            log.info("Samenvatting klaar voor '{}'", result.title.take(50))
            // Source en feedUrl altijd van het originele artikel (voorkomt dat Claude ze overschrijft)
            Pair(result.copy(source = article.source, feedUrl = article.feedUrl), cost)
        } catch (e: Exception) {
            log.error("JSON parsen mislukt voor '{}': {}", article.title, e.message)
            Pair(SummarizedArticle(article.title, article.content.take(500), article.url, article.source, article.feedUrl), cost)
        }
    }

    // Extraheert canonieke topics per nieuwsartikel (voor topic-geschiedenis)
    fun extractNewsTopics(
        items: List<NewsItem>,
        existingTopics: List<String> = emptyList()
    ): Pair<Map<String, List<String>>, Double> {
        if (items.isEmpty()) return Pair(emptyMap(), 0.0)

        val knownTopicsPart = if (existingTopics.isNotEmpty())
            "\n\nBekende onderwerpen (hergebruik deze namen als het over hetzelfde gaat):\n" +
                    existingTopics.take(30).joinToString("\n") { "- $it" }
        else ""

        val articleList = items.take(20).joinToString("\n\n") { item ->
            "ID: \"${item.id}\"\nTitel: \"${item.title}\"\nSamenvatting: \"${item.summary.take(250)}\""
        }

        val prompt = """
            Analyseer de volgende nieuwsartikelen en extraheer voor elk artikel 2-3 canonieke onderwerpen.

            Regels voor onderwerpnamen:
            - Specifiek maar herbruikbaar: "Spring AI framework" (niet "Spring AI 1.0 uitgebracht")
            - Breed genoeg voor meerdere artikelen: "Kubernetes beveiliging" (niet "CVE-2024-12345")
            - 2-5 woorden, in het Nederlands
            - Normaliseer: gebruik voor hetzelfde onderwerp altijd dezelfde naam$knownTopicsPart

            Artikelen:
            $articleList

            Geef ALLEEN een JSON-object terug, geen uitleg:
            {
              "id1": ["Onderwerp A", "Onderwerp B"],
              "id2": ["Onderwerp C"]
            }
        """.trimIndent()

        val (text, cost) = callWithRetry(prompt, summaryModel)
        return try {
            val start = text.indexOf('{')
            val end = text.lastIndexOf('}')
            val json = if (start != -1 && end != -1) text.substring(start, end + 1) else "{}"
            @Suppress("UNCHECKED_CAST")
            val raw = objectMapper.readValue(json, Map::class.java) as Map<*, *>
            val result = mutableMapOf<String, List<String>>()
            raw.forEach { (key, value) ->
                if (key is String && value is List<*>) {
                    val topics = value.filterIsInstance<String>().filter { it.isNotBlank() }
                    if (topics.isNotEmpty()) result[key] = topics
                }
            }
            log.info("News topics geëxtraheerd: {} artikelen", result.size)
            Pair(result, cost)
        } catch (e: Exception) {
            log.error("News topics parsen mislukt: {}", e.message)
            Pair(emptyMap(), cost)
        }
    }

    // ─── RSS-item verwerking ──────────────────────────────────────────────────

    data class RssItemSummary(
        val title: String,
        val summary: String,
        val category: String,
        val topics: List<String> = emptyList()
    )

    data class FeedSelectionResult(
        val url: String,
        val inFeed: Boolean,
        val reason: String
    )

    /**
     * Vat een RSS-item samen, wijs het toe aan een categorie en extraheer topics.
     * Gebruikt de snippet (1000 tekens) uit de RSS feed als bron.
     */
    fun summarizeRssItem(
        item: TavilySearchResult,
        categories: List<CategorySettings>
    ): Pair<RssItemSummary, Double> {
        val categoryList = categories.filter { !it.isSystem && it.enabled }.joinToString(", ") { it.name }
        val datePart = if (item.publishedDate != null) "\nDatum: ${item.publishedDate}" else ""

        val prompt = """
            Je bent een Nederlandse tech-nieuwsredacteur.

            Schrijf een samenvatting van het volgende artikel en wijs het toe aan de beste categorie.

            Titel: ${item.title}
            Bron: ${item.source}
            URL: ${item.url}$datePart

            Inhoud:
            ${item.snippet.take(1000)}

            Beschikbare categorieën: $categoryList

            Richtlijnen:
            - Schrijf een samenvatting van 150-250 woorden
            - Schrijf de INHOUD — wat er is gebeurd, wat is er gezegd, wat zijn de bevindingen
            - Leg NIET uit wat het artikel behandelt — geef gewoon de informatie zelf
            - Schrijf in het Nederlands
            - Wijs de BESTE categorie toe (exact één naam uit de lijst, of "overig" als niets past)
            - Geef 2-3 canonieke onderwerpen (topics) in het Nederlands, elk 2-5 woorden

            Geef ALLEEN een JSON-object, geen uitleg:
            {
              "title": "Artikel titel",
              "summary": "Samenvatting...",
              "category": "Categorie naam",
              "topics": ["Onderwerp 1", "Onderwerp 2"]
            }
        """.trimIndent()

        val (text, cost) = callWithRetry(prompt, summaryModel)
        val json = extractJsonObject(text)
        return try {
            val root = objectMapper.readTree(json)
            val topics = root.path("topics").let { arr ->
                (0 until arr.size()).map { arr.get(it).asText("") }.filter { it.isNotBlank() }
            }
            val result = RssItemSummary(
                title = root.path("title").asText(item.title),
                summary = root.path("summary").asText(""),
                category = root.path("category").asText(""),
                topics = topics
            )
            log.info("RSS-item samenvatting klaar voor '{}' → categorie '{}'", result.title.take(50), result.category)
            Pair(result, cost)
        } catch (e: Exception) {
            log.error("RSS-item samenvatting parsen mislukt voor '{}': {}", item.title, e.message)
            Pair(RssItemSummary(item.title, item.snippet.take(500), ""), cost)
        }
    }

    /**
     * Bepaalt in één batch-aanroep welke nieuwe RSS-items in de feed moeten komen.
     * Geeft een lijst terug van {url, inFeed, reason}.
     */
    fun selectFeedItems(
        newItems: List<RssItem>,
        existingFeedItems: List<RssItem>,
        categories: List<CategorySettings>,
        likedTitles: List<String> = emptyList(),
        dislikedTitles: List<String> = emptyList(),
        topicHistoryContext: String = ""
    ): Pair<List<FeedSelectionResult>, Double> {
        if (newItems.isEmpty()) return Pair(emptyList(), 0.0)

        val enabledCategories = categories.filter { it.enabled && !it.isSystem }

        val newItemsList = newItems.take(60).mapIndexed { i, item ->
            val catExtra = enabledCategories.find { it.name.equals(item.category, ignoreCase = true) }
                ?.extraInstructions?.takeIf { it.isNotBlank() }?.let { " [instructies: $it]" } ?: ""
            "${i + 1}. [${item.category}$catExtra] ${item.title}\n   ${item.summary.take(400)}"
        }.joinToString("\n\n")

        val existingContext = if (existingFeedItems.isNotEmpty()) {
            "\n\nBestaande feed-items van de afgelopen tijd (vermijd dubbele onderwerpen):\n" +
                existingFeedItems.take(30).joinToString("\n") { "- [${it.category}] ${it.title}" }
        } else ""

        val likedPart = if (likedTitles.isNotEmpty())
            "\n\nGeliked door gebruiker (kies vergelijkbare artikelen):\n" +
                likedTitles.take(10).joinToString("\n") { "- \"$it\"" }
        else ""

        val dislikedPart = if (dislikedTitles.isNotEmpty())
            "\n\nNiet relevant gevonden door gebruiker (vermijd vergelijkbare artikelen):\n" +
                dislikedTitles.take(10).joinToString("\n") { "- \"$it\"" }
        else ""

        val historyPart = if (topicHistoryContext.isNotBlank()) "\n\n$topicHistoryContext" else ""

        val today = java.time.LocalDate.now()

        val prompt = """
            Bepaal voor elk van de volgende ${minOf(newItems.size, 60)} nieuwe RSS-artikelen of het in de persoonlijke nieuws-feed van de gebruiker moet komen.

            Vandaag: $today
            $existingContext$likedPart$dislikedPart$historyPart

            Nieuwe artikelen om te beoordelen:
            $newItemsList

            Selectieregels:
            - Selecteer 20-40% van de artikelen voor de feed (kwaliteit boven kwantiteit)
            - Voeg artikelen toe die relevant, actueel en inhoudelijk interessant zijn
            - Vermijd artikelen die al vertegenwoordigd zijn door bestaande feed-items
            - Pas de gebruikers interesses en feedback toe
            - Geef een korte Nederlandse reden (max 15 woorden) waarom het in de feed staat of niet

            Geef ALLEEN een JSON-array, geen uitleg:
            [{"index": 1, "inFeed": true, "reason": "Relevante nieuwe ontwikkeling"}, ...]
        """.trimIndent()

        val (text, cost) = callWithRetry(prompt, summaryModel, maxTokens = 3000)
        return try {
            val start = text.indexOf('[')
            val end = text.lastIndexOf(']')
            val json = if (start != -1 && end != -1) text.substring(start, end + 1) else "[]"
            val root = objectMapper.readTree(json)
            val results = mutableListOf<FeedSelectionResult>()
            for (i in 0 until root.size()) {
                val node = root.get(i)
                val index = node.path("index").asInt(0)
                if (index >= 1 && index <= newItems.size) {
                    results.add(FeedSelectionResult(
                        url = newItems[index - 1].url,
                        inFeed = node.path("inFeed").asBoolean(false),
                        reason = node.path("reason").asText("")
                    ))
                }
            }
            val inFeedCount = results.count { it.inFeed }
            log.info("Feed-selectie: {}/{} artikelen in feed", inFeedCount, newItems.size)
            Pair(results, cost)
        } catch (e: Exception) {
            log.error("Feed-selectie parsen mislukt: {}", e.message)
            Pair(emptyList(), cost)
        }
    }

    /**
     * Genereert een rijke, uitgebreide Nederlandstalige samenvatting (400-600 woorden) voor een FeedItem
     * op basis van een RssItem. Geeft de tekst en de kosten terug.
     */
    fun generateFeedItemSummary(rssItem: RssItem, categories: List<CategorySettings>): Pair<String, Double> {
        val categoryName = categories.find {
            it.id.equals(rssItem.category, ignoreCase = true) ||
            it.name.equals(rssItem.category, ignoreCase = true)
        }?.name ?: rssItem.category

        val prompt = """
            Je bent een Nederlandse tech-nieuwsredacteur die diepgaande artikelen schrijft voor programmeurs en tech-liefhebbers.

            Schrijf een uitgebreide samenvatting van 400-600 woorden over het volgende artikel.

            Titel: ${rssItem.title}
            Bron: ${rssItem.source}
            URL: ${rssItem.url}
            Categorie: $categoryName

            Korte samenvatting: ${rssItem.summary.take(500)}

            Ruwe inhoud:
            ${rssItem.snippet.take(1500)}

            De samenvatting moet de volgende aspecten behandelen:
            1. Wat er precies is gebeurd (gedetailleerd)
            2. Waarom dit relevant is voor een programmeur of tech-liefhebber
            3. Wat de impact en implicaties zijn
            4. Eventuele bredere context

            Richtlijnen:
            - Schrijf vloeiende alinea's, geen opsommingslijst of markdown headers
            - Schrijf in het Nederlands
            - Geef de feitelijke inhoud, leg niet uit wat het artikel behandelt
            - Geen JSON, geen markdown opmaak — alleen platte tekst
        """.trimIndent()

        val (text, cost) = callWithRetry(prompt, summaryModel)
        log.info("FeedItem samenvatting gegenereerd voor '{}': {} tekens", rssItem.title.take(50), text.length)
        return Pair(text.trim(), cost)
    }

    // ── Interne HTTP call ──────────────────────────────────────────────────────

    private fun callWithRetry(prompt: String, model: String, maxTokens: Int = 2000): Pair<String, Double> {
        val body = mapOf(
            "model" to model,
            "max_tokens" to maxTokens,
            "messages" to listOf(mapOf("role" to "user", "content" to prompt))
        )
        val bodyJson = objectMapper.writeValueAsString(body)
        val maxRetries = 4
        var delayMs = 15_000L

        semaphore.acquire()
        try {
            repeat(maxRetries) { attempt ->
                try {
                    val response = client.post()
                        .uri("/v1/messages")
                        .body(bodyJson)
                        .retrieve()
                        .body(String::class.java) ?: return Pair("", 0.0)

                    val root = objectMapper.readTree(response)
                    val usage = root.path("usage")
                    val inputTokens = usage.path("input_tokens").asLong(0)
                    val outputTokens = usage.path("output_tokens").asLong(0)
                    // Haiku: $0.25/MTok input, $1.25/MTok output
                    val costUsd = inputTokens * 0.25e-6 + outputTokens * 1.25e-6
                    log.info("Haiku kosten: {} input, {} output = \${}", inputTokens, outputTokens, "%.5f".format(costUsd))

                    val contentArray = root.path("content")
                    val textParts = mutableListOf<String>()
                    for (i in 0 until contentArray.size()) {
                        val node = contentArray.get(i)
                        if (node.path("type").asText() == "text") {
                            textParts.add(node.path("text").asText())
                        }
                    }
                    return Pair(textParts.joinToString("\n"), costUsd)

                } catch (e: Exception) {
                    val is429 = e.message?.contains("429") == true || e.message?.contains("rate_limit") == true
                    val isConnError = e.message?.contains("handshake") == true
                            || e.message?.contains("Connection") == true
                            || e.message?.contains("I/O error") == true
                            || e.message?.contains("timeout") == true
                    if ((is429 || isConnError) && attempt < maxRetries - 1) {
                        val reden = if (is429) "rate limit" else "verbindingsfout"
                        log.warn("Claude {} (poging {}), wacht {} sec...", reden, attempt + 1, delayMs / 1000)
                        Thread.sleep(delayMs)
                        delayMs *= 2
                    } else {
                        log.error("Claude aanroep mislukt (poging {}): {}", attempt + 1, e.message)
                        return Pair("", 0.0)
                    }
                }
            }
            return Pair("", 0.0)
        } finally {
            semaphore.release()
        }
    }

    private fun extractJsonObject(text: String): String {
        val start = text.indexOf('{')
        val end = text.lastIndexOf('}')
        return if (start != -1 && end != -1) text.substring(start, end + 1) else "{}"
    }
}
