package com.vdzon.newsfeedbackend.websocket

import com.vdzon.newsfeedbackend.model.NewsRequest
import org.springframework.stereotype.Component
import org.springframework.web.socket.CloseStatus
import org.springframework.web.socket.TextMessage
import org.springframework.web.socket.WebSocketSession
import org.springframework.web.socket.handler.TextWebSocketHandler
import tools.jackson.databind.ObjectMapper
import java.util.concurrent.CopyOnWriteArrayList

@Component
class RequestWebSocketHandler(
    private val objectMapper: ObjectMapper
) : TextWebSocketHandler() {

    private val sessions = CopyOnWriteArrayList<WebSocketSession>()

    override fun afterConnectionEstablished(session: WebSocketSession) {
        sessions.add(session)
    }

    override fun afterConnectionClosed(session: WebSocketSession, status: CloseStatus) {
        sessions.remove(session)
    }

    fun broadcast(request: NewsRequest) {
        val json = objectMapper.writeValueAsString(request)
        val message = TextMessage(json)
        sessions.filter { it.isOpen }.forEach { session ->
            try {
                session.sendMessage(message)
            } catch (e: Exception) {
                sessions.remove(session)
            }
        }
    }
}
