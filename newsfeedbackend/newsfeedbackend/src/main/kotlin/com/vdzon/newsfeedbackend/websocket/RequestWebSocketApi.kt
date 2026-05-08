package com.vdzon.newsfeedbackend.websocket

import com.vdzon.newsfeedbackend.model.NewsRequest

/**
 * Contract voor de WebSocket op ws://{host}/ws/requests.
 *
 * Richting:  server → client (broadcast only; client-berichten worden genegeerd)
 * Payload:   volledig NewsRequest object als JSON
 * Trigger:   elke statuswijziging van een NewsRequest
 *            (PROCESSING, DONE, FAILED, CANCELLED)
 *
 * Sessiebeheer:
 *   - Bij verbinding: sessie wordt geregistreerd
 *   - Bij verbreking: sessie wordt verwijderd
 *   - Kapotte verbindingen worden bij de volgende broadcast verwijderd
 */
interface RequestWebSocketApi {
    fun broadcast(request: NewsRequest)
}
