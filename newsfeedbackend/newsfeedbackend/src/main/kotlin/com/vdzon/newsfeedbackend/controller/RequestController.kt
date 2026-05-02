package com.vdzon.newsfeedbackend.controller

import com.vdzon.newsfeedbackend.model.CreateRequestDto
import com.vdzon.newsfeedbackend.model.NewsRequest
import com.vdzon.newsfeedbackend.service.RequestService
import org.springframework.http.HttpStatus
import org.springframework.security.core.Authentication
import org.springframework.web.bind.annotation.DeleteMapping
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.ResponseStatus
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/requests")
class RequestController(private val requestService: RequestService) {

    @GetMapping
    fun getAll(auth: Authentication): List<NewsRequest> = requestService.getAll(auth.name)

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    fun create(auth: Authentication, @RequestBody dto: CreateRequestDto): NewsRequest =
        requestService.create(auth.name, dto)

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    fun delete(auth: Authentication, @PathVariable id: String) =
        requestService.delete(auth.name, id)
}
