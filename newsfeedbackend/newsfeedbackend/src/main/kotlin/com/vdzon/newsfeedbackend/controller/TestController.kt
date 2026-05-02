package com.vdzon.newsfeedbackend.controller

import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/test")
class TestController {

    @GetMapping
    fun test() = mapOf("status" to "ok", "message" to "Personal News Feed backend is running")
}
