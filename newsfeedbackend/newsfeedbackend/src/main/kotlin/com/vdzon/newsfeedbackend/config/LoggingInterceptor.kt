package com.vdzon.newsfeedbackend.config

import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.slf4j.LoggerFactory
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.stereotype.Component
import org.springframework.web.servlet.HandlerInterceptor

@Component
class LoggingInterceptor : HandlerInterceptor {

    private val log = LoggerFactory.getLogger(LoggingInterceptor::class.java)

    override fun preHandle(request: HttpServletRequest, response: HttpServletResponse, handler: Any): Boolean {
        val username = SecurityContextHolder.getContext().authentication?.name ?: "anonymous"
        log.info("--> {} {} [{}]", request.method, request.requestURI, username)
        return true
    }

    override fun afterCompletion(
        request: HttpServletRequest,
        response: HttpServletResponse,
        handler: Any,
        ex: Exception?
    ) {
        val status = response.status
        val username = SecurityContextHolder.getContext().authentication?.name ?: "anonymous"
        if (ex != null) {
            log.warn("<-- {} {} [{}] {} - {}", request.method, request.requestURI, username, status, ex.message)
        } else {
            log.info("<-- {} {} [{}] {}", request.method, request.requestURI, username, status)
        }
    }
}
