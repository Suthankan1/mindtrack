package com.mindtrack.backend.controller;

import com.mindtrack.backend.ai.GeminiService;
import com.mindtrack.backend.model.MoodEntry;
import com.mindtrack.backend.model.StressPattern;
import com.mindtrack.backend.model.User;
import com.mindtrack.backend.repository.UserRepository;
import com.mindtrack.backend.repository.MoodEntryRepository;
import com.mindtrack.backend.service.MoodPatternService;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * REST controller for AI-generated mental health insights.
 */
@RestController
@RequestMapping("/api/ai")
public class AiInsightController {

    private final UserRepository userRepository;
    private final MoodPatternService moodPatternService;
    private final MoodEntryRepository moodEntryRepository;
    private final GeminiService geminiService;
    private final ObjectMapper objectMapper;

    // Cache results by entryId (sentiment won't change for a saved note)
    private final Map<UUID, Map<String, Object>> sentimentCache = new ConcurrentHashMap<>();

    public AiInsightController(
            UserRepository userRepository,
            MoodPatternService moodPatternService,
            MoodEntryRepository moodEntryRepository,
            GeminiService geminiService,
            ObjectMapper objectMapper) {
        this.userRepository = userRepository;
        this.moodPatternService = moodPatternService;
        this.moodEntryRepository = moodEntryRepository;
        this.geminiService = geminiService;
        this.objectMapper = objectMapper;
    }

    /**
     * GET /api/ai/insight/weekly
     *
     * Triggers the weekly mood insight calculation pipeline for the current authenticated user's last 7 days.
     *
     * @param authentication the authenticated user's Spring Security context
     * @return the calculated insight, average score, peak stress day, and entry count.
     */
    @GetMapping("/insight/weekly")
    public ResponseEntity<Map<String, Object>> getWeeklyInsight(Authentication authentication) {
        String email = authentication.getName();
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));

        LocalDateTime end = LocalDateTime.now();
        LocalDateTime start = end.minusDays(7);

        // Count entries in the last 7 days
        int entryCount = moodEntryRepository.findByUserAndTimestampBetweenOrderByTimestampDesc(user, start, end).size();

        StressPattern pattern = moodPatternService.calculateWeeklyPattern(user, start, end);

        Map<String, Object> response = new HashMap<>();
        if (pattern == null) {
            response.put("insight", "Welcome to MindTrack! Complete at least 3 daily mood check-ins to activate your custom pattern engine. In the meantime, start tracking your mood to help identify trends.");
            response.put("weeklyAverage", 0.0);
            response.put("peakDay", "N/A");
            response.put("entryCount", entryCount);
        } else {
            response.put("insight", pattern.getAiInsight());
            response.put("weeklyAverage", pattern.getWeeklyAverage());
            response.put("peakDay", pattern.getPeakStressDay());
            response.put("entryCount", entryCount);
        }

        return ResponseEntity.ok(response);
    }

    /**
     * GET /api/ai/sentiment/{entryId}
     *
     * Analyzes the emotional content of a specific journal note.
     *
     * @param entryId        the ID of the MoodEntry to analyze
     * @param authentication the Spring Security authentication context
     * @return the sentiment analysis result
     */
    @GetMapping("/sentiment/{entryId}")
    public ResponseEntity<Map<String, Object>> getSentiment(
            @PathVariable UUID entryId,
            Authentication authentication) {

        String email = authentication.getName();
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));

        MoodEntry entry = moodEntryRepository.findById(entryId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Mood entry not found"));

        // Verify ownership
        if (!entry.getUser().getId().equals(user.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Access denied: this entry does not belong to you.");
        }

        // Return cached result if available
        if (sentimentCache.containsKey(entryId)) {
            return ResponseEntity.ok(sentimentCache.get(entryId));
        }

        String note = entry.getNote();
        if (note == null || note.trim().length() < 10) {
            Map<String, Object> fallback = new HashMap<>();
            fallback.put("sentiment", "neutral");
            fallback.put("emotionalTone", "neutral");
            fallback.put("themes", java.util.Collections.emptyList());
            fallback.put("confidence", 0.0);
            fallback.put("supportMessage", "No note provided or note is too short to analyze.");
            return ResponseEntity.ok(fallback);
        }

        String prompt = String.format("""
        Analyze the emotional content of this journal note written by someone tracking their mental health:
        
        Note: "%s"
        
        Respond ONLY with valid JSON in this exact format (no markdown, no extra text):
        {
          "sentiment": "positive|neutral|negative",
          "emotionalTone": "one word (e.g. anxious, hopeful, exhausted, content, frustrated)",
          "themes": ["theme1", "theme2"],
          "confidence": 0.0 to 1.0,
          "supportMessage": "one short, warm sentence acknowledging what they wrote"
        }
        """, note);

        String rawResponse = geminiService.generateInsight(prompt);
        if (rawResponse == null || rawResponse.trim().isEmpty()) {
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "Failed to call AI service");
        }

        try {
            // Strip markdown fences
            String cleanedResponse = rawResponse.trim();
            if (cleanedResponse.startsWith("```json")) {
                cleanedResponse = cleanedResponse.substring(7);
            } else if (cleanedResponse.startsWith("```")) {
                cleanedResponse = cleanedResponse.substring(3);
            }
            if (cleanedResponse.endsWith("```")) {
                cleanedResponse = cleanedResponse.substring(0, cleanedResponse.length() - 3);
            }
            cleanedResponse = cleanedResponse.trim();

            Map<String, Object> parsed = objectMapper.readValue(cleanedResponse, Map.class);
            sentimentCache.put(entryId, parsed);
            return ResponseEntity.ok(parsed);
        } catch (Exception e) {
            System.err.println("Failed to parse Gemini sentiment response: " + e.getMessage() + "\nRaw response: " + rawResponse);
            
            // Graceful fallback response on parse failure
            Map<String, Object> fallback = new HashMap<>();
            fallback.put("sentiment", "neutral");
            fallback.put("emotionalTone", "uncertain");
            fallback.put("themes", java.util.Collections.emptyList());
            fallback.put("confidence", 0.0);
            fallback.put("supportMessage", "We are here to support you in every step of your journey.");
            return ResponseEntity.ok(fallback);
        }
    }
}

