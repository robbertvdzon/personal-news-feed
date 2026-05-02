package com.vdzon.newsfeedbackend.service

import com.nimbusds.jose.jwk.source.ImmutableSecret
import org.springframework.beans.factory.annotation.Value
import org.springframework.security.oauth2.jose.jws.MacAlgorithm
import org.springframework.security.oauth2.jwt.JwsHeader
import org.springframework.security.oauth2.jwt.JwtClaimsSet
import org.springframework.security.oauth2.jwt.JwtEncoderParameters
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder
import org.springframework.security.oauth2.jwt.NimbusJwtEncoder
import org.springframework.stereotype.Service
import java.time.Instant
import java.time.temporal.ChronoUnit
import javax.crypto.spec.SecretKeySpec

@Service
class JwtService(@Value("\${app.jwt.secret}") secret: String) {

    private val key = SecretKeySpec(secret.toByteArray(Charsets.UTF_8), "HmacSHA256")
    private val encoder = NimbusJwtEncoder(ImmutableSecret(key))
    private val decoder = NimbusJwtDecoder.withSecretKey(key).build()

    fun generateToken(username: String): String {
        val now = Instant.now()
        val claims = JwtClaimsSet.builder()
            .subject(username)
            .issuedAt(now)
            .expiresAt(now.plus(30, ChronoUnit.DAYS))
            .build()
        val header = JwsHeader.with(MacAlgorithm.HS256).build()
        return encoder.encode(JwtEncoderParameters.from(header, claims)).tokenValue
    }

    fun extractUsername(token: String): String? = try {
        decoder.decode(token).subject
    } catch (e: Exception) {
        null
    }
}
