package com.mindtrack.backend.controller;

import com.mindtrack.backend.dto.*;
import com.mindtrack.backend.model.MoodEntry;
import com.mindtrack.backend.model.User;
import com.mindtrack.backend.repository.MoodEntryRepository;
import com.mindtrack.backend.repository.UserRepository;
import com.mindtrack.backend.service.AiInsightService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

/**
 * REST controller for AI-generated mental health insights.
 */
@RestController
@RequestMapping("/api/ai")
public class AiInsightController {

    private final UserRepository userRepository;
    private final MoodEntryRepository moodEntryRepository;
    private final AiInsightService aiInsightService;

    public AiInsightController(
            UserRepository userRepository,
            MoodEntryRepository moodEntryRepository,
            AiInsightService aiInsightService) {
        this.userRepository = userRepository;
        this.moodEntryRepository = moodEntryRepository;
        this.aiInsightService = aiInsightService;
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

        Map<String, Object> response = aiInsightService.getWeeklyInsight(user);
        return ResponseEntity.ok(response);
    }

    /**
     * GET /api/ai/anomaly/weekly
     *
     * Scans mood logs from the last 30 days to detect anomalies and potential burnout trends.
     *
     * @param authentication the authenticated user's Spring Security context
     * @return the mood anomaly response containing risk level, patterns, suggested actions, and insights.
     */
    @GetMapping("/anomaly/weekly")
    public ResponseEntity<MoodAnomalyResponse> getMoodAnomaly(Authentication authentication) {
        String email = authentication.getName();
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));

        MoodAnomalyResponse response = aiInsightService.getMoodAnomaly(user);
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
    public ResponseEntity<SentimentAnalysisResponse> getSentiment(
            @PathVariable UUID entryId,
            Authentication authentication) {

        String email = authentication.getName();
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));

        SentimentAnalysisResponse response = aiInsightService.getSentiment(entryId, user);
        return ResponseEntity.ok(response);
    }

    /**
     * POST /api/ai/coping/suggest
     *
     * Recommends a personalized coping technique using Gemini based on user mood context.
     *
     * @param request        the coping suggestion payload
     * @param authentication the authenticated user's Spring Security context
     * @return a parsed JSON map containing the recommended technique, duration, reason, and encouragement.
     */
    @PostMapping("/coping/suggest")
    public ResponseEntity<CopingSuggestResponse> getCopingSuggestion(
            @Valid @RequestBody CopingSuggestRequest request,
            Authentication authentication) {

        // Validate user authentication
        String email = authentication.getName();
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));

        List<MoodEntry> recent = moodEntryRepository.findByUserAndTimestampAfterOrderByTimestampDesc(
            user,
            LocalDateTime.now().minusDays(3));
        List<String> recentTags = recent.stream()
            .filter(entry -> entry.getTags() != null)
            .flatMap(entry -> entry.getTags().stream())
            .distinct()
            .limit(5)
            .collect(Collectors.toList());

        if (request.getLastTags() == null || request.getLastTags().isEmpty()) {
            request.setLastTags(recentTags);
        }

        CopingSuggestResponse response = aiInsightService.getCopingSuggestion(request);
        return ResponseEntity.ok(response);
    }

    /**
     * POST /api/ai/crisis/response
     *
     * Generates a warm, empathetic AI response when a user's mood pattern indicates potential crisis risk.
     *
     * @param authentication the authenticated user's Spring Security context
     * @return a map containing the AI-generated message and showCrisisResources flag.
     */
    @PostMapping("/crisis/response")
    public ResponseEntity<Map<String, Object>> getCrisisResponse(Authentication authentication) {
        if (authentication != null) {
            String email = authentication.getName();
            userRepository.findByEmail(email)
                    .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));
        }

        Map<String, Object> response = aiInsightService.getCrisisResponse();
        return ResponseEntity.ok(response);
    }

    /**
     * POST /api/ai/chat
     *
     * MindChat endpoint for multi-turn empathetic AI conversation with mood context.
     *
     * @param request        the chat request containing message, history, and mood context
     * @param authentication the authenticated user's Spring Security context
     * @return a map containing the AI's reply and two suggested follow-up questions
     */
    @PostMapping("/chat")
    public ResponseEntity<ChatResponse> chatWithAi(
            @Valid @RequestBody ChatRequest request,
            Authentication authentication) {

        // Validate user authentication
        User user = null;
        if (authentication != null) {
            String email = authentication.getName();
            user = userRepository.findByEmail(email)
                    .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));
        }

        ChatResponse response = aiInsightService.chatWithAi(request, user);
        return ResponseEntity.ok(response);
    }

    /**
     * POST /api/ai/journal/prompt
     *
     * Generates a personalized journal reflection prompt using Gemini.
     *
     * @param request        the journal prompt generation request
     * @param authentication the authenticated user's Spring Security context
     * @return the personalized prompt response containing title, question, and follow-ups.
     */
    @PostMapping("/journal/prompt")
    public ResponseEntity<JournalPromptResponse> getJournalPrompt(
            @Valid @RequestBody JournalPromptRequest request,
            Authentication authentication) {

        if (authentication != null) {
            String email = authentication.getName();
            userRepository.findByEmail(email)
                    .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));
        }

        JournalPromptResponse response = aiInsightService.getJournalPrompt(request);
        return ResponseEntity.ok(response);
    }

    /**
     * POST /api/ai/mood/reflection
     *
     * Generates a personalized instant AI reflection after mood logging using Gemini.
     *
     * @param request        the reflection request payload
     * @param authentication the authenticated user's Spring Security context
     * @return the generated mood reflection response
     */
    @PostMapping("/mood/reflection")
    public ResponseEntity<MoodReflectionResponse> getMoodReflection(
            @Valid @RequestBody MoodReflectionRequest request,
            Authentication authentication) {

        String email = authentication.getName();
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));

        MoodReflectionResponse response = aiInsightService.getMoodReflection(request, user);
        return ResponseEntity.ok(response);
    }
}
