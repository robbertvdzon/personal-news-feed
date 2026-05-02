package com.vdzon.newsfeedbackend.controller

import com.vdzon.newsfeedbackend.model.CreateRequestDto
import com.vdzon.newsfeedbackend.model.NewsRequest
import com.vdzon.newsfeedbackend.service.RequestService
import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.ResponseStatus
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/requests")
class RequestController(private val requestService: RequestService) {

    @GetMapping
    fun getAll(): List<NewsRequest> = requestService.getAll()

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    fun create(@RequestBody dto: CreateRequestDto): NewsRequest = requestService.create(dto)
}
