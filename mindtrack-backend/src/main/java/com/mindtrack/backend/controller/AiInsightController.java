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
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
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
    public ResponseEntity<Map<String, Object>> getCopingSuggestion(
            @RequestBody CopingSuggestRequest request,
            Authentication authentication) {

        // Validate user authentication
        String email = authentication.getName();
        userRepository.findByEmail(email)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));

        int moodScore = request.getMoodScore();
        String timeOfDay = request.getTimeOfDay();
        double recentAverage = request.getRecentAverage();
        java.util.List<String> lastTags = request.getLastTags();
        if (lastTags == null) {
            lastTags = java.util.Collections.emptyList();
        }

        String prompt = String.format("""
        You are a mental wellness coach inside MindTrack app.
        A user needs a coping recommendation right now.

        Current mood: %d / 5 (1=very stressed, 5=great)
        Time of day: %s
        Recent 7-day average mood: %.1f / 5
        Recent activity tags: %s

        Choose the SINGLE best coping technique for right now from this list:
        - breathing_478: 4-7-8 breathing (best for acute anxiety/panic)
        - breathing_box: Box breathing 4-4-4-4 (best for stress and focus)
        - breathing_deep: Deep breathing 5-5 (best for general tension)
        - grounding: 5-4-3-2-1 sensory grounding (best for overwhelm and dissociation)
        - journaling: Guided journal prompt (best for emotional processing)
        - walk: Short mindful walk suggestion (best for low energy or afternoon slump)

        Respond ONLY with valid JSON (no markdown):
        {
          "technique": "technique_id_from_list",
          "reason": "one sentence explaining why this fits right now",
          "durationMinutes": 5,
          "encouragement": "one warm sentence to motivate them to start"
        }
        """, moodScore, timeOfDay, recentAverage, String.join(", ", lastTags));

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
            return ResponseEntity.ok(parsed);
        } catch (Exception e) {
            System.err.println("Failed to parse Gemini coping suggestion response: " + e.getMessage() + "\nRaw response: " + rawResponse);
            
            // Graceful fallback response on parse failure
            Map<String, Object> fallback = new HashMap<>();
            fallback.put("technique", "breathing_deep");
            fallback.put("reason", "A deep, mindful breath is always a perfect way to center yourself.");
            fallback.put("durationMinutes", 5);
            fallback.put("encouragement", "Take a moment just for yourself right now.");
            return ResponseEntity.ok(fallback);
        }
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

        String prompt = """
        You are a compassionate mental health companion. A user has been experiencing
        consistently low mood (score 1-2 out of 5) for 3 or more days.

        Write a short, warm, non-clinical message that:
        1. Acknowledges that they are going through a difficult time
        2. Reminds them they are not alone
        3. Gently encourages them to reach out to a professional or someone they trust
        4. Does NOT diagnose, does NOT use clinical terms, does NOT be dismissive

        Maximum 4 sentences. Tone: like a caring friend, not a doctor or therapist.
        Do NOT mention suicide or self-harm. Keep it hopeful.
        """;

        String rawResponse = geminiService.generateInsight(prompt);

        Map<String, Object> response = new HashMap<>();
        response.put("message", rawResponse);
        response.put("showCrisisResources", true);

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
    public ResponseEntity<Map<String, Object>> chatWithAi(
            @RequestBody ChatRequest request,
            Authentication authentication) {

        // Validate user authentication
        if (authentication != null) {
            String email = authentication.getName();
            userRepository.findByEmail(email)
                    .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));
        }

        // 1. Build mood context string for the system prompt
        int score = 3;
        double avg = 3.0;
        if (request.getMoodContext() != null) {
            if (request.getMoodContext().getCurrentScore() != null) {
                score = request.getMoodContext().getCurrentScore();
            }
            if (request.getMoodContext().getWeeklyAverage() != null) {
                avg = request.getMoodContext().getWeeklyAverage();
            }
        }

        String systemPrompt = String.format(
                "You are MindTrack's empathetic AI companion. The user's current mood score is %d/5 and their weekly average is %.1f/5. " +
                "You help people reflect on their feelings, not replace professional therapy. Keep responses concise (2-4 sentences). " +
                "Never diagnose. If the user expresses severe distress, gently suggest professional support. " +
                "You MUST respond ONLY with a valid JSON object in this exact format: " +
                "{\"reply\": \"your empathetic response text\", \"suggestedFollowUps\": [\"suggested follow up 1\", \"suggested follow up 2\"]}",
                score, avg
        );

        // 2. Build contents array
        java.util.List<com.mindtrack.backend.dto.GeminiRequest.Content> contents = new java.util.ArrayList<>();

        // Add history
        if (request.getConversationHistory() != null) {
            for (ChatMessage msg : request.getConversationHistory()) {
                String role = msg.getRole();
                // Ensure standard role matching for Gemini ("user" or "model")
                if (role == null || (!role.equals("user") && !role.equals("model"))) {
                    role = "model"; // default fallback for assistant
                }
                contents.add(com.mindtrack.backend.dto.GeminiRequest.Content.builder()
                        .role(role)
                        .parts(java.util.List.of(
                                com.mindtrack.backend.dto.GeminiRequest.Part.builder()
                                        .text(msg.getText())
                                        .build()
                        ))
                        .build());
            }
        }

        // Append new user message
        contents.add(com.mindtrack.backend.dto.GeminiRequest.Content.builder()
                .role("user")
                .parts(java.util.List.of(
                        com.mindtrack.backend.dto.GeminiRequest.Part.builder()
                                .text(request.getMessage())
                                .build()
                ))
                .build());

        // 3. Call Gemini
        String rawResponse = geminiService.generateChatResponse(contents, systemPrompt);

        if (rawResponse == null || rawResponse.trim().isEmpty()) {
            throw new ResponseStatusException(HttpStatus.INTERNAL_SERVER_ERROR, "Failed to call AI service");
        }

        // 4. Parse Response
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
            return ResponseEntity.ok(parsed);
        } catch (Exception e) {
            System.err.println("Failed to parse Gemini chat response as JSON: " + e.getMessage() + "\nRaw response: " + rawResponse);
            
            // Graceful fallback response on parse failure: use the raw response as the reply
            Map<String, Object> fallback = new HashMap<>();
            fallback.put("reply", rawResponse);
            fallback.put("suggestedFollowUps", java.util.List.of("Can you tell me more about that?", "How does that make you feel?"));
            return ResponseEntity.ok(fallback);
        }
    }

    /**
     * DTO for chat requests.
     */
    public static class ChatRequest {
        private String message;
        private java.util.List<ChatMessage> conversationHistory;
        private MoodContext moodContext;

        public String getMessage() {
            return message;
        }

        public void setMessage(String message) {
            this.message = message;
        }

        public java.util.List<ChatMessage> getConversationHistory() {
            return conversationHistory;
        }

        public void setConversationHistory(java.util.List<ChatMessage> conversationHistory) {
            this.conversationHistory = conversationHistory;
        }

        public MoodContext getMoodContext() {
            return moodContext;
        }

        public void setMoodContext(MoodContext moodContext) {
            this.moodContext = moodContext;
        }
    }

    public static class ChatMessage {
        private String role;
        private String text;

        public String getRole() {
            return role;
        }

        public void setRole(String role) {
            this.role = role;
        }

        public String getText() {
            return text;
        }

        public void setText(String text) {
            this.text = text;
        }
    }

    public static class MoodContext {
        private Integer currentScore;
        private Double weeklyAverage;

        public Integer getCurrentScore() {
            return currentScore;
        }

        public void setCurrentScore(Integer currentScore) {
            this.currentScore = currentScore;
        }

        public Double getWeeklyAverage() {
            return weeklyAverage;
        }

        public void setWeeklyAverage(Double weeklyAverage) {
            this.weeklyAverage = weeklyAverage;
        }
    }

    /**
     * Request DTO for AI coping suggestions.
     */
    public static class CopingSuggestRequest {
        private int moodScore;
        private String timeOfDay;
        private double recentAverage;
        private java.util.List<String> lastTags;

        public int getMoodScore() {
            return moodScore;
        }

        public void setMoodScore(int moodScore) {
            this.moodScore = moodScore;
        }

        public String getTimeOfDay() {
            return timeOfDay;
        }

        public void setTimeOfDay(String timeOfDay) {
            this.timeOfDay = timeOfDay;
        }

        public double getRecentAverage() {
            return recentAverage;
        }

        public void setRecentAverage(double recentAverage) {
            this.recentAverage = recentAverage;
        }

        public java.util.List<String> getLastTags() {
            return lastTags;
        }

        public void setLastTags(java.util.List<String> lastTags) {
            this.lastTags = lastTags;
        }
    }
}

