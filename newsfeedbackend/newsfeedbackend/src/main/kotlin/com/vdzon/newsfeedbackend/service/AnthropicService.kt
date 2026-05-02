package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.CategorySettings
import com.vdzon.newsfeedbackend.model.NewsItem
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service
import org.springframework.http.client.SimpleClientHttpRequestFactory
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
    @Value("\${app.anthropic.model}") private val model: String,
    @Value("\${app.anthropic.base-url}") private val baseUrl: String
) {
    private val log = LoggerFactory.getLogger(AnthropicService::class.java)
    private val semaphore = Semaphore(3) // max 3 gelijktijdige Claude calls

    private val client: RestClient by lazy {
        val factory = SimpleClientHttpRequestFactory().apply {
            setConnectTimeout(10_000)       // 10 seconden verbinden
            setReadTimeout(300_000)         // 5 minuten lezen (web search is traag)
        }
        RestClient.builder()
            .requestFactory(factory)
            .baseUrl(baseUrl)
            .defaultHeader("x-api-key", apiKey)
            .defaultHeader("anthropic-version", "2023-06-01")
            .defaultHeader("content-type", "application/json")
            .build()
    }

    fun searchAndSummarizeForCategory(
        category: CategorySettings,
        count: Int
    ): ClaudeSearchResult {
        val extra = if (category.extraInstructions.isNotBlank())
            "\nExtra instructies: ${category.extraInstructions}" else ""

        val prompt = """
            Je bent een Nederlandse tech-nieuwsredacteur.

            Zoek via het web naar de $count meest interessante en recente nieuwsartikelen over "${category.name}".$extra

            Schrijf voor elk gevonden artikel een uitgebreide samenvatting van circa 800 woorden.
            Gebruik meerdere alinea's gescheiden door een lege regel.
            Schrijf de INHOUD van het artikel — wat er is gebeurd, wat er is gezegd, wat de bevindingen zijn.
            Leg NIET uit wat het artikel behandelt of beschrijft. Geef gewoon de informatie zelf.

            Geef je antwoord als ALLEEN een JSON array (geen uitleg, geen markdown):
            [
              {
                "title": "Artikel titel (Nederlands of origineel)",
                "summary": "Eerste alinea.\n\nTweede alinea.\n\nDerde alinea.",
                "url": "originele URL",
                "source": "naam van de bron"
              }
            ]
        """.trimIndent()

        return callClaudeWithSearch(prompt)
    }

    fun searchAndSummarizeForSubject(
        subject: String,
        count: Int,
        extraInstructions: String = ""
    ): ClaudeSearchResult {
        val extra = if (extraInstructions.isNotBlank()) "\nExtra instructies: $extraInstructions" else ""

        val prompt = """
            Je bent een Nederlandse tech-nieuwsredacteur.

            Zoek via het web naar de $count meest interessante en recente nieuwsartikelen over "$subject".$extra

            Schrijf voor elk gevonden artikel een uitgebreide samenvatting van circa 800 woorden.
            Gebruik meerdere alinea's gescheiden door een lege regel.
            Schrijf de INHOUD van het artikel — wat er is gebeurd, wat er is gezegd, wat de bevindingen zijn.
            Leg NIET uit wat het artikel behandelt of beschrijft. Geef gewoon de informatie zelf.

            Geef je antwoord als ALLEEN een JSON array (geen uitleg, geen markdown):
            [
              {
                "title": "Artikel titel",
                "summary": "Eerste alinea.\n\nTweede alinea.\n\nDerde alinea.",
                "url": "originele URL",
                "source": "naam van de bron"
              }
            ]
        """.trimIndent()

        return callClaudeWithSearch(prompt)
    }

    private fun callClaudeWithSearch(prompt: String): ClaudeSearchResult {
        val body = mapOf(
            "model" to model,
            "max_tokens" to 8000,
            "tools" to listOf(
                mapOf("type" to "web_search_20250305", "name" to "web_search")
            ),
            "messages" to listOf(mapOf("role" to "user", "content" to prompt))
        )
        val bodyJson = objectMapper.writeValueAsString(body)

        val maxRetries = 4
        var delayMs = 15_000L  // start met 15 seconden bij 429

        semaphore.acquire()
        log.debug("Semaphore verkregen, {} permits resterend", semaphore.availablePermits())
        try {
        repeat(maxRetries) { attempt ->
            try {
                val response = client.post()
                    .uri("/v1/messages")
                    .body(bodyJson)
                    .retrieve()
                    .body(String::class.java) ?: return ClaudeSearchResult(emptyList(), 0.0)

                val root = objectMapper.readTree(response)

                // Extract cost
                val usage = root.path("usage")
                val inputTokens = usage.path("input_tokens").asLong(0)
                val outputTokens = usage.path("output_tokens").asLong(0)
                val webSearchRequests = usage.path("server_tool_use").path("web_search_requests").asLong(0)
                val costUsd = inputTokens * 3e-6 + outputTokens * 15e-6 + webSearchRequests * 0.01
                log.info("Claude kosten: {} input, {} output, {} web searches = \${}", inputTokens, outputTokens, webSearchRequests, "%.4f".format(costUsd))

                // Extract text from content array (filter for type=text blocks)
                val contentArray = root.path("content")
                val textParts = mutableListOf<String>()
                for (i in 0 until contentArray.size()) {
                    val node = contentArray.get(i)
                    if (node.path("type").asText() == "text") {
                        textParts.add(node.path("text").asText())
                    }
                }
                val text = textParts.joinToString("\n")

                log.debug("Claude response tekst (eerste 500 tekens): {}", text.take(500))

                val json = extractJson(text)
                val articles = objectMapper.readValue<List<SummarizedArticle>>(json)
                log.info("Claude leverde {} artikelen terug", articles.size)
                if (articles.isEmpty()) log.warn("Claude gaf lege lijst terug. Raw JSON: {}", json.take(200))

                return ClaudeSearchResult(articles, costUsd)

            } catch (e: Exception) {
                val is429 = e.message?.contains("429") == true || e.message?.contains("rate_limit") == true
                val isConnectionError = e.message?.contains("handshake") == true
                        || e.message?.contains("Connection") == true
                        || e.message?.contains("I/O error") == true
                        || e.message?.contains("timeout") == true
                if ((is429 || isConnectionError) && attempt < maxRetries - 1) {
                    val reden = if (is429) "rate limit" else "verbindingsfout"
                    log.warn("Claude {} (poging {}), wacht {} seconden...", reden, attempt + 1, delayMs / 1000)
                    Thread.sleep(delayMs)
                    delayMs *= 2
                } else {
                    log.error("Claude web search aanroep mislukt (poging {}): {}", attempt + 1, e.message)
                    return ClaudeSearchResult(emptyList(), 0.0)
                }
            }
        }
        return ClaudeSearchResult(emptyList(), 0.0)
        } finally {
            semaphore.release()
            log.debug("Semaphore vrijgegeven, {} permits beschikbaar", semaphore.availablePermits())
        }
    }

    private fun extractJson(text: String): String {
        val start = text.indexOf('[')
        val end = text.lastIndexOf(']')
        return if (start != -1 && end != -1) text.substring(start, end + 1) else "[]"
    }
}
