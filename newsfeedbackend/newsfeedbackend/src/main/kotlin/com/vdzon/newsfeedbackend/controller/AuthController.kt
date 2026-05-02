package com.vdzon.newsfeedbackend.controller

import com.vdzon.newsfeedbackend.model.AuthRequest
import com.vdzon.newsfeedbackend.model.AuthResponse
import com.vdzon.newsfeedbackend.service.AuthService
import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.ResponseStatus
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/auth")
class AuthController(private val authService: AuthService) {

    @PostMapping("/register")
    @ResponseStatus(HttpStatus.CREATED)
    fun register(@RequestBody request: AuthRequest): AuthResponse =
        authService.register(request.username, request.password)

    @PostMapping("/login")
    fun login(@RequestBody request: AuthRequest): AuthResponse =
        authService.login(request.username, request.password)
}
