package com.vdzon.newsfeedbackend.service

import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.http.client.SimpleClientHttpRequestFactory
import org.springframework.stereotype.Service
import org.springframework.web.client.RestClient
import tools.jackson.databind.ObjectMapper

data class TavilySearchResult(
    val title: String,
    val url: String,
    val source: String,
    val snippet: String,   // kort stukje tekst van de zoekresultaten (geen volledig artikel)
    val publishedDate: String? = null,  // publicatiedatum van het artikel (bijv. "2025-05-04")
    val feedUrl: String? = null         // URL van de RSS feed waaruit dit artikel komt
)

data class TavilyArticle(
    val title: String,
    val url: String,
    val source: String,
    val content: String,   // volledige artikel tekst (via /extract)
    val feedUrl: String? = null         // URL van de RSS feed waaruit dit artikel komt
)

@Service
class TavilyService(
    private val objectMapper: ObjectMapper,
    @Value("\${app.tavily.api-key}") private val apiKey: String
) {
    private val log = LoggerFactory.getLogger(TavilyService::class.java)

    private val client: RestClient by lazy {
        val factory = SimpleClientHttpRequestFactory().apply {
            setConnectTimeout(10_000)
            setReadTimeout(30_000)
        }
        RestClient.builder()
            .requestFactory(factory)
            .baseUrl("https://api.tavily.com")
            .defaultHeader("Authorization", "Bearer $apiKey")
            .defaultHeader("Content-Type", "application/json")
            .build()
    }

    // Fase 1: zoeken — geeft titels + snippets terug, geen volledige tekst
    fun search(query: String, maxResults: Int = 20, days: Int = 2, includeDomains: List<String> = emptyList()): List<TavilySearchResult> {
        val bodyMap = mutableMapOf<String, Any>(
            "query" to query,
            "search_depth" to "advanced",
            "max_results" to maxResults,
            "days" to days,
            "include_raw_content" to false,
            "include_answer" to false
        )
        if (includeDomains.isNotEmpty()) {
            bodyMap["include_domains"] = includeDomains
            log.info("Tavily domein-filter: {}", includeDomains)
        }
        val body = bodyMap.toMap()

        log.info("Tavily zoekopdracht: '{}'  (max {} resultaten)", query, maxResults)
        return try {
            val response = client.post()
                .uri("/search")
                .body(objectMapper.writeValueAsString(body))
                .retrieve()
                .body(String::class.java) ?: return emptyList()

            val root = objectMapper.readTree(response)
            val results = root.path("results")
            val articles = mutableListOf<TavilySearchResult>()

            for (i in 0 until results.size()) {
                val r = results.get(i)
                val url = r.path("url").asText()
                val title = r.path("title").asText()
                val snippet = r.path("content").asText("")
                val publishedDate = r.path("published_date").asText("").takeIf { it.isNotBlank() }

                if (title.isNotBlank()) {
                    articles.add(TavilySearchResult(
                        title = title,
                        url = url,
                        source = extractDomain(url),
                        snippet = snippet.take(500),
                        publishedDate = publishedDate
                    ))
                }
            }

            log.info("Tavily '{}': {} resultaten gevonden", query, articles.size)
            articles
        } catch (e: Exception) {
            log.error("Tavily zoeken mislukt voor '{}': {}", query, e.message)
            emptyList()
        }
    }

    // Fase 3: volledige tekst ophalen voor geselecteerde URLs via /extract
    fun extractContent(urls: List<String>): Map<String, String> {
        if (urls.isEmpty()) return emptyMap()

        val body = mapOf("urls" to urls)

        log.info("Tavily extract voor {} URLs", urls.size)
        return try {
            val response = client.post()
                .uri("/extract")
                .body(objectMapper.writeValueAsString(body))
                .retrieve()
                .body(String::class.java) ?: return emptyMap()

            val root = objectMapper.readTree(response)
            val results = root.path("results")
            val contentMap = mutableMapOf<String, String>()

            for (i in 0 until results.size()) {
                val r = results.get(i)
                val url = r.path("url").asText()
                val content = r.path("raw_content").asText("")
                if (url.isNotBlank() && content.isNotBlank()) {
                    contentMap[url] = content.take(8000)
                }
            }

            log.info("Tavily extract: {}/{} URLs succesvol", contentMap.size, urls.size)
            contentMap
        } catch (e: Exception) {
            log.error("Tavily extract mislukt: {}", e.message)
            emptyMap()
        }
    }

    private fun extractDomain(url: String): String {
        return try {
            val host = java.net.URI(url).host ?: url
            host.removePrefix("www.")
        } catch (_: Exception) {
            url
        }
    }
}
