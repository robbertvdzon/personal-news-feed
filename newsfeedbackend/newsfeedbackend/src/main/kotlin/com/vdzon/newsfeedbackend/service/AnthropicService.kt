package com.vdzon.newsfeedbackend.service

import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.http.client.SimpleClientHttpRequestFactory
import org.springframework.stereotype.Service
import org.springframework.web.client.RestClient
import tools.jackson.databind.ObjectMapper
import tools.jackson.module.kotlin.readValue
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

    // Genereert een goede Engelse zoekquery voor Tavily op basis van categorie + extra instructies
    fun generateSearchQuery(categoryName: String, extraInstructions: String): String {
        val instructionsPart = if (extraInstructions.isNotBlank())
            "\n\nAdditional context about what the user is interested in:\n$extraInstructions"
        else ""

        val prompt = """
            You are a search query expert. Generate a concise and effective English news search query for Tavily.

            Category: $categoryName$instructionsPart

            Rules:
            - Write ONLY the search query, nothing else
            - In English
            - 3-8 words, focused on recent news
            - Include "news" or relevant temporal terms if appropriate
            - Target the most relevant and specific aspect based on the context
        """.trimIndent()

        val (text, _) = callWithRetry(prompt, summaryModel)
        val query = text.trim().removeSurrounding("\"")
        log.info("Gegenereerde zoekquery voor '{}': '{}'", categoryName, query)
        return query.ifBlank { "$categoryName news" }
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
