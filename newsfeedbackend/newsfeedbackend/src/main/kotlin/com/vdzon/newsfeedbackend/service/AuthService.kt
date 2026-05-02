package com.vdzon.newsfeedbackend.service

import com.vdzon.newsfeedbackend.model.AuthResponse
import com.vdzon.newsfeedbackend.model.User
import org.springframework.http.HttpStatus
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder
import org.springframework.stereotype.Service
import org.springframework.web.server.ResponseStatusException
import java.util.UUID

@Service
class AuthService(
    private val userStorage: UserStorageService,
    private val jwtService: JwtService
) {
    private val passwordEncoder = BCryptPasswordEncoder()

    fun register(username: String, password: String): AuthResponse {
        if (username.isBlank() || password.length < 4) {
            throw ResponseStatusException(HttpStatus.BAD_REQUEST, "Ongeldige invoer")
        }
        if (userStorage.existsByUsername(username)) {
            throw ResponseStatusException(HttpStatus.CONFLICT, "Gebruikersnaam al in gebruik")
        }
        val user = User(
            id = UUID.randomUUID().toString(),
            username = username,
            passwordHash = passwordEncoder.encode(password) ?: throw ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "Wachtwoord hash mislukt")
        )
        userStorage.save(user)
        return AuthResponse(token = jwtService.generateToken(username), username = username)
    }

    fun login(username: String, password: String): AuthResponse {
        val user = userStorage.findByUsername(username)
            ?: throw ResponseStatusException(HttpStatus.UNAUTHORIZED, "Ongeldige inloggegevens")
        if (!passwordEncoder.matches(password, user.passwordHash)) {
            throw ResponseStatusException(HttpStatus.UNAUTHORIZED, "Ongeldige inloggegevens")
        }
        return AuthResponse(token = jwtService.generateToken(username), username = username)
    }
}
