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
class ElevenLabsTtsService(
    @Value("\${app.elevenlabs.api-key:}") private val apiKey: String,
    @Value("\${app.elevenlabs.base-url:https://api.elevenlabs.io}") private val baseUrl: String,
    @Value("\${app.elevenlabs.voice-interviewer:pNInz6obpgDQGcFmaJgB}") private val voiceInterviewer: String,
    @Value("\${app.elevenlabs.voice-guest:VR6AewLTigWG4xSOukaG}") private val voiceGuest: String,
    private val objectMapper: ObjectMapper
) {
    private val log = LoggerFactory.getLogger(ElevenLabsTtsService::class.java)

    private val client: RestClient by lazy {
        val factory = SimpleClientHttpRequestFactory().apply {
            setConnectTimeout(15_000)
            setReadTimeout(180_000)
        }
        RestClient.builder()
            .requestFactory(factory)
            .baseUrl(baseUrl)
            .defaultHeader("xi-api-key", apiKey)
            .defaultHeader("Content-Type", "application/json")
            .defaultHeader("Accept", "audio/mpeg")
            .build()
    }

    // Genereert MP3 audio met twee Nederlandse ElevenLabs-stemmen.
    // Geeft (durationSeconds, costUsd) terug.
    fun generateAudio(scriptText: String, outputFile: File): Pair<Int, Double> {
        if (apiKey.isBlank()) {
            throw RuntimeException("ELEVENLABS_API_KEY is niet ingesteld")
        }

        val lines = scriptText.lines()
            .map { it.trim() }
            .filter { it.isNotBlank() }

        val buffer = ByteArrayOutputStream()
        var totalChars = 0
        var segmentCount = 0

        for (line in lines) {
            val (voiceId, text) = when {
                line.startsWith("INTERVIEWER:") -> voiceInterviewer to line.removePrefix("INTERVIEWER:").trim()
                line.startsWith("GAST:") -> voiceGuest to line.removePrefix("GAST:").trim()
                else -> continue
            }
            if (text.isBlank()) continue

            val bodyJson = objectMapper.writeValueAsString(mapOf(
                "text" to text,
                "model_id" to "eleven_multilingual_v2",
                "voice_settings" to mapOf(
                    "stability" to 0.5,
                    "similarity_boost" to 0.75,
                    "style" to 0.0,
                    "use_speaker_boost" to true
                )
            ))

            try {
                val (statusCode, bytes) = client.post()
                    .uri("/v1/text-to-speech/$voiceId")
                    .body(bodyJson)
                    .exchange { _, response ->
                        Pair(response.statusCode.value(), response.body.readBytes())
                    }

                if (statusCode == 200 && bytes != null && bytes.isNotEmpty()) {
                    buffer.write(bytes)
                    totalChars += text.length
                    segmentCount++
                    log.debug("ElevenLabs segment {}: {} chars, {} bytes, stem={}", segmentCount, text.length, bytes.size, voiceId)
                } else if (bytes != null) {
                    val errorBody = bytes.toString(Charsets.UTF_8).take(300)
                    log.error("ElevenLabs TTS HTTP {}: {}", statusCode, errorBody)
                    throw RuntimeException("ElevenLabs TTS HTTP $statusCode: $errorBody")
                }
            } catch (e: RuntimeException) {
                throw e
            } catch (e: Exception) {
                log.error("ElevenLabs TTS fout (stem={}): {}", voiceId, e.message)
                throw RuntimeException("ElevenLabs TTS segment mislukt: ${e.message}", e)
            }
        }

        if (buffer.size() == 0) {
            log.warn("Geen audio gegenereerd via ElevenLabs — leeg script of alle segmenten mislukt")
            outputFile.parentFile?.mkdirs()
            outputFile.writeBytes(ByteArray(0))
            return Pair(0, 0.0)
        }

        outputFile.parentFile?.mkdirs()
        outputFile.writeBytes(buffer.toByteArray())
        log.info("ElevenLabs audio opgeslagen: {} ({} bytes, {} segmenten)", outputFile.name, buffer.size(), segmentCount)

        // Schatting duur: ~150 woorden/min, ~5 tekens/woord
        val estimatedSeconds = ((totalChars / 5.0 / 150.0) * 60).toInt()
        // ElevenLabs Creator-plan: ~$0,30 per 1000 tekens
        val costUsd = totalChars.toDouble() / 1_000.0 * 0.30
        log.info("ElevenLabs klaar: ~{} sec, {} tekens, \${}", estimatedSeconds, totalChars, "%.4f".format(costUsd))
        return Pair(estimatedSeconds, costUsd)
    }
}
