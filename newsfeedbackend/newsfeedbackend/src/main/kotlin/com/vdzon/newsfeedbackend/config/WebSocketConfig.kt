package com.vdzon.newsfeedbackend.config

import com.vdzon.newsfeedbackend.websocket.RequestWebSocketHandler
import org.springframework.context.annotation.Configuration
import org.springframework.web.socket.config.annotation.EnableWebSocket
import org.springframework.web.socket.config.annotation.WebSocketConfigurer
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry

@Configuration
@EnableWebSocket
class WebSocketConfig(
    private val requestWebSocketHandler: RequestWebSocketHandler
) : WebSocketConfigurer {

    override fun registerWebSocketHandlers(registry: WebSocketHandlerRegistry) {
        registry.addHandler(requestWebSocketHandler, "/ws/requests")
            .setAllowedOriginPatterns("*")
    }
}
