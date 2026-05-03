package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.NewsItem
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.http.client.SimpleClientHttpRequestFactory
import org.springframework.stereotype.Service
import org.springframework.web.client.RestClient
import tools.jackson.databind.ObjectMapper
import tools.jackson.module.kotlin.readValue
import java.time.Instant
import java.util.UUID
import java.util.concurrent.Semaphore

data class SummarizedArticle(
    val title: String,
    val summary: String,
    val url: String,
    val source: String
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

    // Fase 2: selecteert de beste artikelen op basis van titels + snippets + feedback
    fun selectArticles(
        articles: List<TavilySearchResult>,
        categoryName: String,
        extraInstructions: String,
        preferredCount: Int,
        maxCount: Int,
        likedTitles: List<String> = emptyList(),
        dislikedTitles: List<String> = emptyList(),
        recentTitles: List<String> = emptyList()
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

        val recentPart = if (recentTitles.isNotEmpty())
            "\n\nAlready in the feed recently (avoid overlapping topics):\n" +
                    recentTitles.take(20).joinToString("\n") { "- \"$it\"" }
        else ""

        val articleList = articles.mapIndexed { i, a ->
            "${i + 1}. Title: \"${a.title}\"\n   Snippet: ${a.snippet.take(200)}"
        }.joinToString("\n\n")

        val prompt = """
            You are a news curator. Select the $preferredCount to $maxCount most relevant articles for the user.

            Category: $categoryName$instructionsPart$likedPart$dislikedPart$recentPart

            Articles to evaluate:
            $articleList

            Rules:
            - Select between $preferredCount and $maxCount articles
            - Prefer articles that match the user's specific interests and liked examples
            - Avoid articles similar to disliked examples
            - Avoid articles that overlap in topic with recently shown items
            - Avoid duplicate topics within this selection
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

    // Genereert een dagelijks redactioneel overzicht van alle gevonden artikelen
    fun generateDailySummary(articles: List<NewsItem>, categories: List<String>): Pair<NewsItem, Double> {
        if (articles.isEmpty()) {
            val empty = NewsItem(
                id = UUID.randomUUID().toString(),
                title = "Dagelijks overzicht",
                summary = "Geen artikelen beschikbaar voor het dagelijks overzicht.",
                url = "",
                category = "dagelijks-overzicht",
                timestamp = Instant.now().toString(),
                source = "Daily Summary",
                isSummary = true
            )
            return Pair(empty, 0.0)
        }

        val categoryList = categories.joinToString(", ")
        val articleList = articles.take(50).mapIndexed { i, a ->
            "${i + 1}. [${a.category}] ${a.title}\n   ${a.summary.take(200)}"
        }.joinToString("\n\n")

        val prompt = """
            Je bent een Nederlandse techredacteur die een dagelijkse briefing schrijft.

            Schrijf een dagelijks redactioneel overzicht van 500-700 woorden op basis van de onderstaande nieuwsartikelen.

            Categorieën van vandaag: $categoryList

            Artikelen:
            $articleList

            Richtlijnen:
            - Schrijf in vloeiend, journalistiek Nederlands
            - Groepeer per thema of categorie — NIET als opsomming
            - Benoem de hot topics van vandaag
            - Schrijf als een redactioneel essay, niet als een lijst
            - Vermeld geen artikelnummers, URLs of bronnamen letterlijk
            - Gebruik meerdere alinea's, gescheiden door een lege regel
            - Eindig met een korte conclusie of vooruitblik

            Geef je antwoord als ALLEEN een JSON object (geen uitleg, geen markdown):
            {
              "title": "Dagelijks overzicht — [thema of datum]",
              "summary": "Eerste alinea.\n\nTweede alinea.\n\nDerde alinea."
            }
        """.trimIndent()

        val (text, cost) = callWithRetry(prompt, summaryModel)
        val json = extractJsonObject(text)
        return try {
            val root = objectMapper.readTree(json)
            val title = root.path("title").asText("Dagelijks overzicht")
            val summaryText = root.path("summary").asText(text.take(1000))
            val item = NewsItem(
                id = UUID.randomUUID().toString(),
                title = title,
                summary = summaryText,
                url = "",
                category = "dagelijks-overzicht",
                timestamp = Instant.now().toString(),
                source = "Daily Summary",
                isSummary = true
            )
            log.info("Dagelijks overzicht gegenereerd: '{}'", title)
            Pair(item, cost)
        } catch (e: Exception) {
            log.error("Dagelijks overzicht parsen mislukt: {}", e.message)
            val item = NewsItem(
                id = UUID.randomUUID().toString(),
                title = "Dagelijks overzicht",
                summary = text.take(1000),
                url = "",
                category = "dagelijks-overzicht",
                timestamp = Instant.now().toString(),
                source = "Daily Summary",
                isSummary = true
            )
            Pair(item, cost)
        }
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
            Pair(result, cost)
        } catch (e: Exception) {
            log.error("JSON parsen mislukt voor '{}': {}", article.title, e.message)
            Pair(SummarizedArticle(article.title, article.content.take(500), article.url, article.source), cost)
        }
    }

    // ── Interne HTTP call ──────────────────────────────────────────────────────

    private fun callWithRetry(prompt: String, model: String): Pair<String, Double> {
        val body = mapOf(
            "model" to model,
            "max_tokens" to 2000,
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
