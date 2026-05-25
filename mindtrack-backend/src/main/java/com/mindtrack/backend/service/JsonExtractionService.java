package com.mindtrack.backend.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.mindtrack.backend.dto.ChatResponse;
import com.mindtrack.backend.dto.CopingSuggestResponse;
import com.mindtrack.backend.dto.SentimentAnalysisResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

@Service
public class JsonExtractionService {

    private static final Logger log = LoggerFactory.getLogger(JsonExtractionService.class);
    private final ObjectMapper objectMapper;

    public JsonExtractionService(ObjectMapper objectMapper) {
        this.objectMapper = objectMapper;
    }

    /**
     * Cleans markdown fences and extracts the outer-most JSON object structure
     * from potentially cluttered Gemini text outputs.
     */
    public String cleanAndExtractJson(String rawInput) {
        if (rawInput == null) {
            return null;
        }
        String cleaned = rawInput.trim();

        // 1. Strip markdown fences if present
        if (cleaned.startsWith("```json")) {
            cleaned = cleaned.substring(7);
        } else if (cleaned.startsWith("```")) {
            cleaned = cleaned.substring(3);
        }
        if (cleaned.endsWith("```")) {
            cleaned = cleaned.substring(0, cleaned.length() - 3);
        }
        cleaned = cleaned.trim();

        // 2. Extract first outer JSON object if there is surrounding text
        int firstBrace = cleaned.indexOf('{');
        int lastBrace = cleaned.lastIndexOf('}');
        if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
            cleaned = cleaned.substring(firstBrace, lastBrace + 1);
        }

        return cleaned;
    }

    /**
     * Cleans, parses, and validates the required fields of the requested class.
     * Guaranteed to be privacy-safe: never logs raw notes or raw AI outputs.
     */
    public <T> T extractAndParse(String rawInput, Class<T> valueType) {
        if (rawInput == null || rawInput.trim().isEmpty()) {
            throw new IllegalArgumentException("Raw AI response input is empty");
        }

        String cleaned = null;
        try {
            cleaned = cleanAndExtractJson(rawInput);
            T parsedObj = objectMapper.readValue(cleaned, valueType);
            validateRequiredFields(parsedObj);
            return parsedObj;
        } catch (Exception e) {
            // Privacy protection: do not print rawInput or cleaned to console/logs
            log.error("Failed to parse Gemini response for {}: {}", valueType.getSimpleName(), e.getMessage());
            throw new RuntimeException("JSON extraction or validation failed: " + e.getMessage(), e);
        }
    }

    /**
     * Checks if the parsed DTO contains all mandatory fields to prevent empty/broken UI.
     */
    private <T> void validateRequiredFields(T object) {
        if (object == null) {
            throw new IllegalArgumentException("Parsed object is null");
        }

        if (object instanceof SentimentAnalysisResponse) {
            SentimentAnalysisResponse r = (SentimentAnalysisResponse) object;
            if (r.getSentiment() == null || r.getSentiment().trim().isEmpty() ||
                r.getEmotionalTone() == null || r.getEmotionalTone().trim().isEmpty() ||
                r.getThemes() == null ||
                r.getSupportMessage() == null || r.getSupportMessage().trim().isEmpty()) {
                throw new IllegalArgumentException("Missing required fields in SentimentAnalysisResponse");
            }
        } else if (object instanceof CopingSuggestResponse) {
            CopingSuggestResponse r = (CopingSuggestResponse) object;
            if (r.getTechnique() == null || r.getTechnique().trim().isEmpty() ||
                r.getReason() == null || r.getReason().trim().isEmpty() ||
                r.getEncouragement() == null || r.getEncouragement().trim().isEmpty()) {
                throw new IllegalArgumentException("Missing required fields in CopingSuggestResponse");
            }
        } else if (object instanceof ChatResponse) {
            ChatResponse r = (ChatResponse) object;
            if (r.getReply() == null || r.getReply().trim().isEmpty()) {
                throw new IllegalArgumentException("Missing required fields in ChatResponse");
            }
        }
    }
}
