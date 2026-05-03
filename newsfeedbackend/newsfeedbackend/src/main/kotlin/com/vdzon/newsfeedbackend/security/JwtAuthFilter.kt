package com.vdzon.newsfeedbackend.security

import com.vdzon.newsfeedbackend.service.JwtService
import jakarta.servlet.FilterChain
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken
import org.springframework.security.core.context.SecurityContextHolder
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource
import org.springframework.stereotype.Component
import org.springframework.web.filter.OncePerRequestFilter

@Component
class JwtAuthFilter(private val jwtService: JwtService) : OncePerRequestFilter() {

    override fun doFilterInternal(
        request: HttpServletRequest,
        response: HttpServletResponse,
        chain: FilterChain
    ) {
        // Token kan via Authorization-header of via ?token= query-param komen
        // (de query-param-variant is nodig voor audio-streaming in webbrowsers)
        val rawToken: String? = run {
            val authHeader = request.getHeader("Authorization")
            if (authHeader != null && authHeader.startsWith("Bearer ")) {
                authHeader.removePrefix("Bearer ")
            } else {
                request.getParameter("token")
            }
        }
        if (rawToken != null) {
            val username = jwtService.extractUsername(rawToken)
            if (username != null && SecurityContextHolder.getContext().authentication == null) {
                val auth = UsernamePasswordAuthenticationToken(username, null, emptyList())
                auth.details = WebAuthenticationDetailsSource().buildDetails(request)
                SecurityContextHolder.getContext().authentication = auth
            }
        }
        chain.doFilter(request, response)
    }
}
