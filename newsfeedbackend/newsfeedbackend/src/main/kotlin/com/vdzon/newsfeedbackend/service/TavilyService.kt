package com.vdzon.newsfeedbackend.service

import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.http.client.SimpleClientHttpRequestFactory
import org.springframework.stereotype.Service
import org.springframework.web.client.RestClient
import tools.jackson.databind.ObjectMapper

data class TavilyArticle(
    val title: String,
    val url: String,
    val source: String,
    val content: String   // full cleaned article text from Tavily
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

    fun search(query: String, maxResults: Int = 5): List<TavilyArticle> {
        val body = mapOf(
            "query" to query,
            "search_depth" to "advanced",
            "max_results" to maxResults,
            "include_raw_content" to true,
            "include_answer" to false
        )

        log.info("Tavily zoekopdracht: '{}'  (max {} resultaten)", query, maxResults)
        return try {
            val response = client.post()
                .uri("/search")
                .body(objectMapper.writeValueAsString(body))
                .retrieve()
                .body(String::class.java) ?: return emptyList()

            val root = objectMapper.readTree(response)
            val results = root.path("results")
            val articles = mutableListOf<TavilyArticle>()

            for (i in 0 until results.size()) {
                val r = results.get(i)
                val url = r.path("url").asText()
                val title = r.path("title").asText()
                // rawContent bevat het volledige artikel; content is een snippet als fallback
                val rawContent = r.path("raw_content").asText("")
                val snippet = r.path("content").asText("")
                val content = if (rawContent.length > 200) rawContent else snippet
                val source = extractDomain(url)

                if (title.isNotBlank() && content.isNotBlank()) {
                    articles.add(TavilyArticle(
                        title = title,
                        url = url,
                        source = source,
                        content = content.take(8000)  // max 8000 tekens per artikel
                    ))
                }
            }

            log.info("Tavily '{}': {} resultaten", query, articles.size)
            articles
        } catch (e: Exception) {
            log.error("Tavily aanroep mislukt voor '{}': {}", query, e.message)
            emptyList()
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
