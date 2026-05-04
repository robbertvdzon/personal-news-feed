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
                    buffer.write(prepareSegment(bytes, segmentCount + 1))
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

    /**
     * Bereidt een MP3-segment voor op aaneenschakeling:
     * 1. Strip ID3v2 (begin) en ID3v1 (eind)
     * 2. Strip Xing/Info VBR-header frame
     *
     * ElevenLabs voegt per segment zowel een ID3v2-tag als een Xing/Info VBR-frame toe.
     * Het Xing/Info-frame bevat het totale aantal frames van DIT segment; wanneer meerdere
     * segmenten aaneengeschakeld worden stopt de speler na het eerste segment omdat hij
     * denkt dat het bestand dan klaar is.
     */
    private fun prepareSegment(bytes: ByteArray, segmentNumber: Int): ByteArray {
        val noId3 = stripId3Tags(bytes)
        val noVbr = stripXingFrame(noId3, segmentNumber)
        return noVbr
    }

    /**
     * Strip ID3v2-header (begin) en ID3v1-tag (eind).
     */
    private fun stripId3Tags(bytes: ByteArray): ByteArray {
        var start = 0
        var end = bytes.size

        // Strip ID3v2 aan het begin (magic "ID3")
        if (bytes.size >= 10 &&
            bytes[0] == 'I'.code.toByte() &&
            bytes[1] == 'D'.code.toByte() &&
            bytes[2] == '3'.code.toByte()
        ) {
            // Synchsafe integer (4 × 7 bits) in bytes 6-9
            val size = ((bytes[6].toInt() and 0x7F) shl 21) or
                       ((bytes[7].toInt() and 0x7F) shl 14) or
                       ((bytes[8].toInt() and 0x7F) shl 7) or
                        (bytes[9].toInt() and 0x7F)
            start = 10 + size
            log.debug("ID3v2 gestript: {} bytes overgeslagen", start)
        }

        // Strip ID3v1 aan het eind (magic "TAG", vaste lengte 128 bytes)
        if (end - start >= 128 &&
            bytes[end - 128] == 'T'.code.toByte() &&
            bytes[end - 127] == 'A'.code.toByte() &&
            bytes[end - 126] == 'G'.code.toByte()
        ) {
            end -= 128
            log.debug("ID3v1 gestript: 128 bytes verwijderd aan het eind")
        }

        return if (start == 0 && end == bytes.size) bytes
        else bytes.copyOfRange(start, end)
    }

    /**
     * Zoekt het eerste MPEG-frame en verwijdert het als het een Xing/Info VBR-header bevat.
     * Dit frame bevat metadata over het aantal frames in DIT segment; zonder verwijdering
     * stopt de speler na het eerste segment.
     */
    private fun stripXingFrame(data: ByteArray, segmentNumber: Int): ByteArray {
        var i = 0
        while (i < data.size - 4) {
            // MPEG sync woord: 0xFF gevolgd door byte met top 3 bits gezet
            if (data[i].toInt() and 0xFF == 0xFF && data[i + 1].toInt() and 0xE0 == 0xE0) {
                val frameSize = getMpegFrameSize(data, i)
                if (frameSize > 0 && i + frameSize <= data.size) {
                    // Bepaal grootte van side-information (afhankelijk van MPEG-versie en kanalen)
                    val b1 = data[i + 1].toInt() and 0xFF
                    val b3 = data[i + 3].toInt() and 0xFF
                    val mpegVersion = (b1 shr 3) and 0x03   // 3=MPEG1, 2=MPEG2, 0=MPEG2.5
                    val channelMode = (b3 shr 6) and 0x03   // 3=Mono, anders stereo/joint/dual
                    val mono = channelMode == 3
                    val sideInfoSize = when {
                        mpegVersion == 3 && !mono -> 32  // MPEG1 stereo
                        mpegVersion == 3 && mono  -> 17  // MPEG1 mono
                        !mono                     -> 17  // MPEG2/2.5 stereo
                        else                      -> 9   // MPEG2/2.5 mono
                    }

                    val tagOffset = i + 4 + sideInfoSize
                    if (tagOffset + 4 <= data.size) {
                        val tag = String(data, tagOffset, 4, Charsets.ISO_8859_1)
                        if (tag == "Xing" || tag == "Info" || tag == "LAME") {
                            log.debug(
                                "Segment {}: Xing/Info VBR-frame ('{}') gevonden op offset {}, " +
                                "framegrootte {} bytes — gestript",
                                segmentNumber, tag, i, frameSize
                            )
                            return data.copyOfRange(i + frameSize, data.size)
                        }
                    }
                    // Eerste frame is geen VBR-header → niets strippen
                    break
                }
            }
            i++
        }
        return data
    }

    /**
     * Berekent de grootte (in bytes) van een MPEG Layer III (MP3) frame
     * op basis van de 4-byte frame-header op [offset].
     * Geeft -1 terug als het geen geldig MP3-frame is.
     */
    private fun getMpegFrameSize(data: ByteArray, offset: Int): Int {
        if (offset + 4 > data.size) return -1

        val b1 = data[offset + 1].toInt() and 0xFF
        val b2 = data[offset + 2].toInt() and 0xFF

        val mpegVersion = (b1 shr 3) and 0x03  // 3=MPEG1, 2=MPEG2, 0=MPEG2.5, 1=reserved
        val layer       = (b1 shr 1) and 0x03  // 1=LayerIII, 2=LayerII, 3=LayerI

        if (mpegVersion == 1) return -1  // reserved
        if (layer != 1) return -1        // alleen Layer III (MP3)

        val bitrateIdx    = (b2 shr 4) and 0x0F
        val sampleRateIdx = (b2 shr 2) and 0x03
        val padding       = (b2 shr 1) and 0x01

        if (bitrateIdx == 0 || bitrateIdx == 15) return -1  // vrij / ongeldig
        if (sampleRateIdx == 3) return -1                    // gereserveerd

        // Bitrate tabellen voor Layer III (kbps → bps)
        val bitratesV1 = intArrayOf(0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0)
        val bitratesV2 = intArrayOf(0, 8,  16, 24, 32, 40, 48, 56, 64,  80,  96,  112, 128, 144, 160, 0)
        val bitrate = (if (mpegVersion == 3) bitratesV1[bitrateIdx] else bitratesV2[bitrateIdx]) * 1000

        // Sample rate tabellen (Hz)
        val srV1  = intArrayOf(44100, 48000, 32000)
        val srV2  = intArrayOf(22050, 24000, 16000)
        val srV25 = intArrayOf(11025, 12000,  8000)
        val sampleRate = when (mpegVersion) {
            3    -> srV1[sampleRateIdx]
            2    -> srV2[sampleRateIdx]
            0    -> srV25[sampleRateIdx]
            else -> return -1
        }

        // Framegrootte: floor(144 * bitrate / sampleRate) + padding
        return 144 * bitrate / sampleRate + padding
    }
}
