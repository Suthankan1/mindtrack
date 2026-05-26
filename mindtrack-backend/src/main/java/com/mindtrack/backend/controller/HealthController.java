package com.mindtrack.backend.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Lightweight health endpoint for uptime checks and external analyzers.
 * Returns backend status and AI availability without exposing secret values.
 */
@RestController
public class HealthController {

    /** Injected only to check presence — value is never returned to clients. */
    @Value("${gemini.api.key:}")
    private String geminiApiKey;

    @GetMapping("/api/health")
    public ResponseEntity<Map<String, Object>> health() {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("status", "UP");
        body.put("app", "MindTrack");
        body.put("sdg", "3 - Good Health and Well-being");
        body.put("aiEnabled", geminiApiKey != null && !geminiApiKey.isBlank());
        return ResponseEntity.ok(body);
    }
}