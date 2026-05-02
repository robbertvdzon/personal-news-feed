package com.vdzon.newsfeedbackend.service

import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service
import org.springframework.web.client.RestClient
import tools.jackson.databind.ObjectMapper
import tools.jackson.module.kotlin.readValue

data class SummarizedArticle(
    val title: String,
    val summary: String,
    val url: String,
    val source: String
)

@Service
class AnthropicService(
    private val objectMapper: ObjectMapper,
    @Value("\${app.anthropic.api-key}") private val apiKey: String,
    @Value("\${app.anthropic.model}") private val model: String,
    @Value("\${app.anthropic.base-url}") private val baseUrl: String
) {
    private val log = LoggerFactory.getLogger(AnthropicService::class.java)

    private val client: RestClient by lazy {
        RestClient.builder()
            .baseUrl(baseUrl)
            .defaultHeader("x-api-key", apiKey)
            .defaultHeader("anthropic-version", "2023-06-01")
            .defaultHeader("content-type", "application/json")
            .build()
    }

    fun summarizeForCategory(
        articles: List<RawArticle>,
        category: String,
        categoryName: String,
        count: Int,
        extraInstructions: String = ""
    ): List<SummarizedArticle> {
        if (articles.isEmpty()) return emptyList()

        val articleList = articles.take(40).joinToString("\n---\n") { a ->
            "Titel: ${a.title}\nBron: ${a.source}\nURL: ${a.url}\nBeschrijving: ${a.description}"
        }

        val extra = if (extraInstructions.isNotBlank()) "\nExtra instructies: $extraInstructions" else ""

        val prompt = """
            Je bent een Nederlandse tech-nieuwsredacteur.

            Selecteer de $count meest interessante en recente artikelen over "$categoryName" uit de lijst hieronder.$extra

            Schrijf voor elk artikel een uitgebreide samenvatting van circa 800 woorden.
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

            Artikelen:
            $articleList
        """.trimIndent()

        return callClaude(prompt)
    }

    fun summarizeForSubject(
        articles: List<RawArticle>,
        subject: String,
        count: Int,
        extraInstructions: String = ""
    ): List<SummarizedArticle> {
        if (articles.isEmpty()) return emptyList()

        val articleList = articles.take(60).joinToString("\n---\n") { a ->
            "Titel: ${a.title}\nBron: ${a.source}\nURL: ${a.url}\nBeschrijving: ${a.description}"
        }

        val extra = if (extraInstructions.isNotBlank()) "\nExtra instructies: $extraInstructions" else ""

        val prompt = """
            Je bent een Nederlandse tech-nieuwsredacteur.

            Zoek uit de lijst hieronder de $count artikelen die het meest relevant zijn voor het onderwerp: "$subject".$extra
            Als er te weinig relevante artikelen zijn, kies dan de best passende.

            Schrijf voor elk artikel een uitgebreide samenvatting van circa 800 woorden.
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

            Artikelen:
            $articleList
        """.trimIndent()

        return callClaude(prompt)
    }

    private fun callClaude(prompt: String): List<SummarizedArticle> {
        val body = mapOf(
            "model" to model,
            "max_tokens" to 16000,
            "messages" to listOf(mapOf("role" to "user", "content" to prompt))
        )

        return try {
            val response = client.post()
                .uri("/v1/messages")
                .body(objectMapper.writeValueAsString(body))
                .retrieve()
                .body(String::class.java) ?: return emptyList()

            val root = objectMapper.readTree(response)
            val text = root.path("content").path(0).path("text").asText()

            val json = extractJson(text)
            objectMapper.readValue<List<SummarizedArticle>>(json)
        } catch (e: Exception) {
            log.error("Claude aanroep mislukt: {}", e.message)
            emptyList()
        }
    }

    private fun extractJson(text: String): String {
        val start = text.indexOf('[')
        val end = text.lastIndexOf(']')
        return if (start != -1 && end != -1) text.substring(start, end + 1) else "[]"
    }
}
