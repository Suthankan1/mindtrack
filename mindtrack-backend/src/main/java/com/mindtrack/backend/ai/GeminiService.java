package com.mindtrack.backend.ai;

import com.mindtrack.backend.dto.GeminiRequest;
import com.mindtrack.backend.dto.GeminiResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class GeminiService {

    private static final Logger log = LoggerFactory.getLogger(GeminiService.class);

    @Value("${gemini.api.key}")
    private String apiKey;

    @Value("${gemini.model:gemini-2.5-flash}")
    private String model;

    private final WebClient webClient;
    private final Map<String, CacheEntry> cache = new ConcurrentHashMap<>();
    private static final long CACHE_TTL_MS = 6 * 60 * 60 * 1000L; // 6 hours

    public GeminiService(WebClient geminiWebClient) {
        this.webClient = geminiWebClient;
    }

    /**
     * Exposes a WebClient bean pointing to https://generativelanguage.googleapis.com.
     * Declared as static to prevent circular dependency during injection into the service.
     */
    @Bean
    public static WebClient geminiWebClient() {
        return WebClient.builder()
                .baseUrl("https://generativelanguage.googleapis.com")
                .build();
    }

    /**
     * Generates a mental health insight based on the provided user context prompt.
     * Uses an MD5 prompt hash for 6-hour caching to optimize API usage and rate limits.
     * Wraps request in try-catch to guarantee graceful failure fallbacks.
     */
    public String generateInsight(String prompt) {
        return generateInsight(prompt, null, null);
    }

    /**
     * Generates a mental health insight with custom response MIME type and temperature controls.
     */
    public String generateInsight(String prompt, String responseMimeType, Double temperature) {
        if (prompt == null || prompt.trim().isEmpty()) {
            return "Prompt cannot be empty.";
        }

        String key = generateMd5(prompt);
        CacheEntry entry = cache.get(key);
        if (entry != null && !entry.isExpired()) {
            return entry.value;
        }

        try {
            GeminiRequest.GenerationConfig generationConfig = null;
            if (responseMimeType != null || temperature != null) {
                generationConfig = GeminiRequest.GenerationConfig.builder()
                        .responseMimeType(responseMimeType)
                        .temperature(temperature)
                        .build();
            }

            GeminiRequest request = GeminiRequest.builder()
                    .contents(List.of(
                            GeminiRequest.Content.builder()
                                    .parts(List.of(
                                            GeminiRequest.Part.builder()
                                                    .text(prompt)
                                                    .build()
                                    ))
                                    .build()
                    ))
                    .generationConfig(generationConfig)
                    .build();

            GeminiResponse response = webClient.post()
                    .uri(uriBuilder -> uriBuilder
                            .path("/v1beta/models/{model}:generateContent")
                            .queryParam("key", apiKey)
                            .build(model))
                    .contentType(MediaType.APPLICATION_JSON)
                    .bodyValue(request)
                    .retrieve()
                    .bodyToMono(GeminiResponse.class)
                    .block();

            if (response != null && response.getCandidates() != null && !response.getCandidates().isEmpty()) {
                GeminiResponse.Candidate candidate = response.getCandidates().get(0);
                if (candidate.getContent() != null && candidate.getContent().getParts() != null && !candidate.getContent().getParts().isEmpty()) {
                    String text = candidate.getContent().getParts().get(0).getText();
                    if (text != null) {
                        cache.put(key, new CacheEntry(text, CACHE_TTL_MS));
                        return text;
                    }
                }
            }

            return "No insight generated. Please check back later.";

        } catch (Exception e) {
            log.error("Gemini API call failed: {}", e.getMessage());
            return "Unable to generate AI mental health insight at this time. Please continue tracking your mood to help identify patterns.";
        }
    }

    /**
     * Generates a multi-turn chat response using system instructions and full conversation history.
     */
    public String generateChatResponse(List<GeminiRequest.Content> contents, String systemInstruction) {
        return generateChatResponse(contents, systemInstruction, null, null);
    }

    /**
     * Generates a multi-turn chat response with custom response MIME type and temperature controls.
     */
    public String generateChatResponse(List<GeminiRequest.Content> contents, String systemInstruction, String responseMimeType, Double temperature) {
        if (contents == null || contents.isEmpty()) {
            return "Conversation history is empty.";
        }

        try {
            GeminiRequest.GenerationConfig generationConfig = null;
            if (responseMimeType != null || temperature != null) {
                generationConfig = GeminiRequest.GenerationConfig.builder()
                        .responseMimeType(responseMimeType)
                        .temperature(temperature)
                        .build();
            }

            GeminiRequest request = GeminiRequest.builder()
                    .contents(contents)
                    .systemInstruction(systemInstruction != null ?
                            GeminiRequest.SystemInstruction.builder()
                                    .parts(List.of(
                                            GeminiRequest.Part.builder()
                                                    .text(systemInstruction)
                                                    .build()
                                    ))
                                    .build() : null)
                    .generationConfig(generationConfig)
                    .build();

            GeminiResponse response = webClient.post()
                    .uri(uriBuilder -> uriBuilder
                            .path("/v1beta/models/{model}:generateContent")
                            .queryParam("key", apiKey)
                            .build(model))
                    .contentType(MediaType.APPLICATION_JSON)
                    .bodyValue(request)
                    .retrieve()
                    .bodyToMono(GeminiResponse.class)
                    .block();

            if (response != null && response.getCandidates() != null && !response.getCandidates().isEmpty()) {
                GeminiResponse.Candidate candidate = response.getCandidates().get(0);
                if (candidate.getContent() != null && candidate.getContent().getParts() != null && !candidate.getContent().getParts().isEmpty()) {
                    String text = candidate.getContent().getParts().get(0).getText();
                    if (text != null) {
                        return text;
                    }
                }
            }

            return "No response generated. Please check back later.";

        } catch (Exception e) {
            log.error("Gemini Chat API call failed: {}", e.getMessage());
            return "Unable to generate AI chat response at this time.";
        }
    }

    /**
     * Computes the MD5 hex string for a given prompt string key.
     */
    private String generateMd5(String source) {
        try {
            MessageDigest md = MessageDigest.getInstance("MD5");
            byte[] array = md.digest(source.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : array) {
                sb.append(Integer.toHexString((b & 0xFF) | 0x100).substring(1, 3));
            }
            return sb.toString();
        } catch (NoSuchAlgorithmException e) {
            return String.valueOf(source.hashCode());
        }
    }

    /**
     * Inner class representing a cache entry with value and expiration timestamp.
     */
    private static class CacheEntry {
        private final String value;
        private final long expiryTime;

        public CacheEntry(String value, long ttlMs) {
            this.value = value;
            this.expiryTime = System.currentTimeMillis() + ttlMs;
        }

        public boolean isExpired() {
            return System.currentTimeMillis() > expiryTime;
        }
    }
}
