package com.vdzon.newsfeedbackend.service

import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.http.client.SimpleClientHttpRequestFactory
import org.springframework.stereotype.Service
import org.springframework.web.client.RestClient
import tools.jackson.databind.ObjectMapper
import java.io.ByteArrayOutputStream
import java.io.File

@Service
class OpenAITtsService(
    @Value("\${app.openai.api-key}") private val apiKey: String,
    @Value("\${app.openai.base-url:https://api.openai.com}") private val baseUrl: String,
    private val objectMapper: ObjectMapper
) {
    private val log = LoggerFactory.getLogger(OpenAITtsService::class.java)

    private val client: RestClient by lazy {
        val factory = SimpleClientHttpRequestFactory().apply {
            setConnectTimeout(15_000)
            setReadTimeout(120_000)
        }
        RestClient.builder()
            .requestFactory(factory)
            .baseUrl(baseUrl)
            .defaultHeader("Authorization", "Bearer $apiKey")
            .defaultHeader("Content-Type", "application/json")
            .build()
    }

    // Genereert MP3 audio van een podcast-script met twee stemmen.
    // Geeft (durationSeconds, costUsd) terug.
    fun generateAudio(scriptText: String, outputFile: File): Pair<Int, Double> {
        val lines = scriptText.lines()
            .map { it.trim() }
            .filter { it.isNotBlank() }

        val buffer = ByteArrayOutputStream()
        var totalChars = 0
        var segmentCount = 0

        for (line in lines) {
            val (voice, text) = when {
                line.startsWith("INTERVIEWER:") -> "onyx" to line.removePrefix("INTERVIEWER:").trim()
                line.startsWith("GAST:") -> "alloy" to line.removePrefix("GAST:").trim()
                else -> continue  // regels zonder spreker-prefix overslaan
            }
            if (text.isBlank()) continue

            val bodyJson = objectMapper.writeValueAsString(mapOf(
                "model" to "tts-1",
                "input" to text,
                "voice" to voice,
                "response_format" to "mp3",
                "speed" to 1.2
            ))

            try {
                val (statusCode, bytes) = client.post()
                    .uri("/v1/audio/speech")
                    .body(bodyJson)
                    .exchange { _, response ->
                        Pair(response.statusCode.value(), response.body.readBytes())
                    }

                if (statusCode == 200 && bytes != null && bytes.isNotEmpty()) {
                    buffer.write(bytes)
                    totalChars += text.length
                    segmentCount++
                    log.debug("TTS segment {}: {} chars, {} bytes, stem={}", segmentCount, text.length, bytes.size, voice)
                } else if (bytes != null) {
                    val errorBody = bytes.toString(Charsets.UTF_8).take(300)
                    log.error("OpenAI TTS HTTP {}: {}", statusCode, errorBody)
                    throw RuntimeException("OpenAI TTS HTTP $statusCode: $errorBody")
                }
            } catch (e: RuntimeException) {
                throw e   // doorgoooien zodat PodcastProcessor FAILED zet
            } catch (e: Exception) {
                log.error("TTS fout voor segment (stem={}): {}", voice, e.message)
                throw RuntimeException("TTS segment mislukt: ${e.message}", e)
            }
        }

        if (buffer.size() == 0) {
            log.warn("Geen audio gegenereerd — leeg script of alle segmenten mislukt")
            outputFile.parentFile?.mkdirs()
            outputFile.writeBytes(ByteArray(0))
            return Pair(0, 0.0)
        }

        outputFile.parentFile?.mkdirs()
        outputFile.writeBytes(buffer.toByteArray())
        log.info("Audio opgeslagen: {} ({} bytes, {} segmenten)", outputFile.name, buffer.size(), segmentCount)

        // Schatting: ~150 woorden/min, ~5 tekens/woord
        val estimatedSeconds = ((totalChars / 5.0 / 150.0) * 60).toInt()
        // OpenAI TTS-1: $15 per 1 miljoen tekens
        val costUsd = totalChars.toDouble() / 1_000_000.0 * 15.0
        log.info("TTS klaar: ~{} sec, {} tekens, \${}", estimatedSeconds, totalChars, "%.4f".format(costUsd))
        return Pair(estimatedSeconds, costUsd)
    }
}
