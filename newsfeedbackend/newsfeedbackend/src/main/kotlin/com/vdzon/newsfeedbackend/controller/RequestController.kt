package com.vdzon.newsfeedbackend.controller

import com.vdzon.newsfeedbackend.api.RequestsApi
import com.vdzon.newsfeedbackend.model.CreateRequestDto
import com.vdzon.newsfeedbackend.model.NewsRequest
import com.vdzon.newsfeedbackend.service.RequestService
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.web.bind.annotation.RestController

@RestController
class RequestController(private val requestService: RequestService) : RequestsApi {

    private val username get() = SecurityContextHolder.getContext().authentication!!.name

    override fun getRequests(): ResponseEntity<List<NewsRequest>> =
        ResponseEntity.ok(requestService.getAll(username))

    override fun createRequest(createRequestDto: CreateRequestDto): ResponseEntity<NewsRequest> =
        ResponseEntity.status(HttpStatus.CREATED).body(requestService.create(username, createRequestDto))

    override fun deleteRequest(id: String): ResponseEntity<Unit> {
        requestService.delete(username, id)
        return ResponseEntity.noContent().build()
    }

    override fun rerunRequest(id: String): ResponseEntity<NewsRequest> =
        ResponseEntity.ok(requestService.rerun(username, id))

    override fun cancelRequest(id: String): ResponseEntity<Unit> {
        requestService.cancel(username, id)
        return ResponseEntity.noContent().build()
    }
}
