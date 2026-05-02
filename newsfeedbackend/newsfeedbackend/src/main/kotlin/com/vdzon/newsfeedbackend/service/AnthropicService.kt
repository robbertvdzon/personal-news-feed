package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.CategorySettings
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.http.client.SimpleClientHttpRequestFactory
import org.springframework.stereotype.Service
import org.springframework.web.client.RestClient
import tools.jackson.databind.ObjectMapper
import tools.jackson.module.kotlin.readValue
import java.util.concurrent.Semaphore

// Fase 1: gevonden artikel (titel + url + korte beschrijving)
data class ArticleRef(
    val title: String,
    val url: String,
    val source: String,
    val description: String
)

// Fase 2: volledig samengevat artikel
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
            setConnectTimeout(10_000)   // 10 seconden verbinden
            setReadTimeout(120_000)     // 2 minuten per call (web search ~60s, summary ~15s)
        }
        RestClient.builder()
            .requestFactory(factory)
            .baseUrl(baseUrl)
            .defaultHeader("x-api-key", apiKey)
            .defaultHeader("anthropic-version", "2023-06-01")
            .defaultHeader("content-type", "application/json")
            .build()
    }

    // ── Fase 1: zoek interessante artikelen via web search ────────────────────

    fun findArticles(subject: String, count: Int, extraInstructions: String = ""): Pair<List<ArticleRef>, Double> {
        val extra = if (extraInstructions.isNotBlank()) "\nExtra instructies: $extraInstructions" else ""
        val prompt = """
            Je bent een Nederlandse tech-nieuwsredacteur.

            Zoek via het web naar de $count meest interessante en recente nieuwsartikelen over "$subject".$extra

            Geef je antwoord als ALLEEN een JSON array (geen uitleg, geen markdown):
            [
              {
                "title": "Artikel titel",
                "url": "originele URL",
                "source": "naam van de bron",
                "description": "één zin beschrijving van het artikel"
              }
            ]
        """.trimIndent()

        val (text, cost) = callClaudeWithSearch(prompt)
        val json = extractJson(text)
        return try {
            val refs = objectMapper.readValue<List<ArticleRef>>(json)
            log.info("Fase 1: {} artikelen gevonden voor '{}'", refs.size, subject)
            Pair(refs, cost)
        } catch (e: Exception) {
            log.error("Fase 1 JSON parsen mislukt voor '{}': {}", subject, e.message)
            Pair(emptyList(), cost)
        }
    }

    fun findArticlesForCategory(category: CategorySettings, count: Int): Pair<List<ArticleRef>, Double> {
        val extra = if (category.extraInstructions.isNotBlank())
            "\nExtra instructies: ${category.extraInstructions}" else ""
        val prompt = """
            Je bent een Nederlandse tech-nieuwsredacteur.

            Zoek via het web naar de $count meest interessante en recente nieuwsartikelen over "${category.name}".$extra

            Geef je antwoord als ALLEEN een JSON array (geen uitleg, geen markdown):
            [
              {
                "title": "Artikel titel",
                "url": "originele URL",
                "source": "naam van de bron",
                "description": "één zin beschrijving van het artikel"
              }
            ]
        """.trimIndent()

        val (text, cost) = callClaudeWithSearch(prompt)
        val json = extractJson(text)
        return try {
            val refs = objectMapper.readValue<List<ArticleRef>>(json)
            log.info("Fase 1: {} artikelen gevonden voor categorie '{}'", refs.size, category.name)
            Pair(refs, cost)
        } catch (e: Exception) {
            log.error("Fase 1 JSON parsen mislukt voor '{}': {}", category.name, e.message)
            Pair(emptyList(), cost)
        }
    }

    // ── Fase 2: schrijf samenvatting voor één artikel ─────────────────────────

    fun summarizeArticle(article: ArticleRef, subject: String): Pair<SummarizedArticle, Double> {
        val prompt = """
            Je bent een Nederlandse tech-nieuwsredacteur.

            Schrijf een uitgebreide samenvatting van circa 400 woorden over het volgende artikel over "$subject":

            Titel: ${article.title}
            Bron: ${article.source}
            URL: ${article.url}
            Beschrijving: ${article.description}

            Gebruik meerdere alinea's gescheiden door een lege regel.
            Schrijf de INHOUD — wat er is gebeurd, wat er is gezegd, wat de bevindingen zijn.
            Leg NIET uit wat het artikel behandelt. Geef gewoon de informatie zelf.

            Geef je antwoord als ALLEEN een JSON object (geen uitleg, geen markdown):
            {
              "title": "Artikel titel",
              "summary": "Eerste alinea.\n\nTweede alinea.\n\nDerde alinea.",
              "url": "originele URL",
              "source": "naam van de bron"
            }
        """.trimIndent()

        val (text, cost) = callClaude(prompt)
        val json = extractJsonObject(text)
        return try {
            val article = objectMapper.readValue<SummarizedArticle>(json)
            log.info("Fase 2: samenvatting klaar voor '{}'", article.title.take(50))
            Pair(article, cost)
        } catch (e: Exception) {
            log.error("Fase 2 JSON parsen mislukt: {}", e.message)
            // Fallback: gebruik beschrijving als samenvatting
            Pair(SummarizedArticle(article.title, article.description, article.url, article.source), cost)
        }
    }

    // ── Interne HTTP calls ────────────────────────────────────────────────────

    private fun callClaudeWithSearch(prompt: String): Pair<String, Double> {
        val body = mapOf(
            "model" to model,
            "max_tokens" to 2000,
            "tools" to listOf(
                mapOf("type" to "web_search_20250305", "name" to "web_search")
            ),
            "messages" to listOf(mapOf("role" to "user", "content" to prompt))
        )
        return callWithRetry(body, useSearch = true)
    }

    private fun callClaude(prompt: String): Pair<String, Double> {
        val body = mapOf(
            "model" to model,
            "max_tokens" to 2000,
            "messages" to listOf(mapOf("role" to "user", "content" to prompt))
        )
        return callWithRetry(body, useSearch = false)
    }

    private fun callWithRetry(body: Map<String, Any>, useSearch: Boolean): Pair<String, Double> {
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
                    val webSearchRequests = if (useSearch)
                        usage.path("server_tool_use").path("web_search_requests").asLong(0) else 0L
                    val costUsd = inputTokens * 3e-6 + outputTokens * 15e-6 + webSearchRequests * 0.01
                    log.info("Claude kosten: {} input, {} output, {} searches = \${}", inputTokens, outputTokens, webSearchRequests, "%.4f".format(costUsd))

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

    private fun extractJson(text: String): String {
        val start = text.indexOf('[')
        val end = text.lastIndexOf(']')
        return if (start != -1 && end != -1) text.substring(start, end + 1) else "[]"
    }

    private fun extractJsonObject(text: String): String {
        val start = text.indexOf('{')
        val end = text.lastIndexOf('}')
        return if (start != -1 && end != -1) text.substring(start, end + 1) else "{}"
    }
}
