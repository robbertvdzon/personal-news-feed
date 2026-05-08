package com.vdzon.newsfeedbackend.controller

import com.vdzon.newsfeedbackend.api.AuthApi
import com.vdzon.newsfeedbackend.model.AuthRequest
import com.vdzon.newsfeedbackend.model.AuthResponse
import com.vdzon.newsfeedbackend.service.AuthService
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.RestController

@RestController
class AuthController(private val authService: AuthService) : AuthApi {

    override fun register(authRequest: AuthRequest): ResponseEntity<AuthResponse> =
        ResponseEntity.status(HttpStatus.CREATED)
            .body(authService.register(authRequest.username, authRequest.password))

    override fun login(authRequest: AuthRequest): ResponseEntity<AuthResponse> =
        ResponseEntity.ok(authService.login(authRequest.username, authRequest.password))
}
