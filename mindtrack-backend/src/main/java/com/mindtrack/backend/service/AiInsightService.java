package com.mindtrack.backend.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.mindtrack.backend.ai.GeminiService;
import com.mindtrack.backend.dto.*;
import com.mindtrack.backend.model.MoodEntry;
import com.mindtrack.backend.model.StressPattern;
import com.mindtrack.backend.model.User;
import com.mindtrack.backend.repository.MoodEntryRepository;
import com.mindtrack.backend.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class AiInsightService {

    private static final Logger log = LoggerFactory.getLogger(AiInsightService.class);

    private final UserRepository userRepository;
    private final MoodPatternService moodPatternService;
    private final MoodEntryRepository moodEntryRepository;
    private final GeminiService geminiService;
    private final ObjectMapper objectMapper;
    private final JsonExtractionService jsonExtractionService;

    // Cache results by entryId (sentiment won't change for a saved note)
    private final Map<UUID, SentimentAnalysisResponse> sentimentCache = new ConcurrentHashMap<>();

    public AiInsightService(
            UserRepository userRepository,
            MoodPatternService moodPatternService,
            MoodEntryRepository moodEntryRepository,
            GeminiService geminiService,
            ObjectMapper objectMapper,
            JsonExtractionService jsonExtractionService) {
        this.userRepository = userRepository;
        this.moodPatternService = moodPatternService;
        this.moodEntryRepository = moodEntryRepository;
        this.geminiService = geminiService;
        this.objectMapper = objectMapper;
        this.jsonExtractionService = jsonExtractionService;
    }

    /**
     * Triggers the weekly mood insight calculation pipeline for the user's last 7 days.
     */
    public Map<String, Object> getWeeklyInsight(User user) {
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
            response.put("aiAvailable", false);
        } else {
            response.put("insight", pattern.getAiInsight());
            response.put("weeklyAverage", pattern.getWeeklyAverage());
            response.put("peakDay", pattern.getPeakStressDay());
            response.put("entryCount", entryCount);
            boolean available = pattern.getAiInsight() != null &&
                    !pattern.getAiInsight().startsWith("Unable to generate AI") &&
                    !pattern.getAiInsight().startsWith("No insight generated");
            response.put("aiAvailable", available);
        }

        return response;
    }

    /**
     * Analyzes the emotional content of a specific journal note.
     */
    public SentimentAnalysisResponse getSentiment(UUID entryId, User user) {
        MoodEntry entry = moodEntryRepository.findById(entryId)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND, "Mood entry not found"));

        // Verify ownership
        if (!entry.getUser().getId().equals(user.getId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN, "Access denied: this entry does not belong to you.");
        }

        // Return cached result if available
        if (sentimentCache.containsKey(entryId)) {
            return sentimentCache.get(entryId);
        }

        String note = entry.getNote();
        if (note == null || note.trim().length() < 10) {
            SentimentAnalysisResponse fallback = SentimentAnalysisResponse.builder()
                    .sentiment("neutral")
                    .emotionalTone("neutral")
                    .themes(Collections.emptyList())
                    .confidence(0.0)
                    .supportMessage("No note provided or note is too short to analyze.")
                    .build();
            return fallback;
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

        try {
            String rawResponse = geminiService.generateInsight(prompt, "application/json", 0.1);
            SentimentAnalysisResponse parsed = jsonExtractionService.extractAndParse(rawResponse, SentimentAnalysisResponse.class);
            sentimentCache.put(entryId, parsed);
            return parsed;
        } catch (Exception e) {
            log.error("Failed to process Gemini sentiment response: {}", e.getMessage());
            
            SentimentAnalysisResponse fallback = SentimentAnalysisResponse.builder()
                    .sentiment("neutral")
                    .emotionalTone("uncertain")
                    .themes(Collections.emptyList())
                    .confidence(0.0)
                    .supportMessage("We are here to support you in every step of your journey.")
                    .aiAvailable(false)
                    .build();
            return fallback;
        }
    }

    /**
     * Recommends a personalized coping technique using Gemini based on user mood context.
     */
    public CopingSuggestResponse getCopingSuggestion(CopingSuggestRequest request) {
        int moodScore = request.getMoodScore();
        String timeOfDay = request.getTimeOfDay();
        double recentAverage = request.getRecentAverage();
        List<String> lastTags = request.getLastTags();
        if (lastTags == null) {
            lastTags = Collections.emptyList();
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

        try {
            String rawResponse = geminiService.generateInsight(prompt, "application/json", 0.1);
            CopingSuggestResponse parsed = jsonExtractionService.extractAndParse(rawResponse, CopingSuggestResponse.class);
            return parsed;
        } catch (Exception e) {
            log.error("Failed to process Gemini coping suggestion: {}", e.getMessage());
            
            CopingSuggestResponse fallback = CopingSuggestResponse.builder()
                    .technique("breathing_deep")
                    .reason("A deep, mindful breath is always a perfect way to center yourself.")
                    .durationMinutes(5)
                    .encouragement("Take a moment just for yourself right now.")
                    .aiAvailable(false)
                    .build();
            return fallback;
        }
    }

    /**
     * Generates a warm, empathetic AI response when a user's mood pattern indicates potential crisis risk.
     */
    public Map<String, Object> getCrisisResponse() {
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

        String rawResponse = geminiService.generateInsight(prompt, null, 0.7);

        Map<String, Object> response = new HashMap<>();
        response.put("message", rawResponse);
        response.put("showCrisisResources", true);
        
        boolean available = rawResponse != null &&
                !rawResponse.startsWith("Unable to generate AI") &&
                !rawResponse.startsWith("No insight generated");
        response.put("aiAvailable", available);

        return response;
    }

    /**
     * MindChat endpoint for multi-turn empathetic AI conversation with mood context.
     */
    public ChatResponse chatWithAi(ChatRequest request) {
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
        List<com.mindtrack.backend.dto.GeminiRequest.Content> contents = new ArrayList<>();

        // Add history
        if (request.getConversationHistory() != null) {
            for (ChatMessageDto msg : request.getConversationHistory()) {
                String role = msg.getRole();
                // Ensure standard role matching for Gemini ("user" or "model")
                if (role == null || (!role.equals("user") && !role.equals("model"))) {
                    role = "model"; // default fallback for assistant
                }
                contents.add(com.mindtrack.backend.dto.GeminiRequest.Content.builder()
                        .role(role)
                        .parts(List.of(
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
                .parts(List.of(
                        com.mindtrack.backend.dto.GeminiRequest.Part.builder()
                                .text(request.getMessage())
                                .build()
                ))
                .build());

        // 3. Call Gemini and Parse Response
        try {
            String rawResponse = geminiService.generateChatResponse(contents, systemPrompt, "application/json", 0.2);
            ChatResponse parsed = jsonExtractionService.extractAndParse(rawResponse, ChatResponse.class);
            return parsed;
        } catch (Exception e) {
            log.error("Failed to process Gemini chat response: {}", e.getMessage());
            
            ChatResponse fallback = ChatResponse.builder()
                    .reply("I'm here for you. Although my advanced AI features are temporarily offline, I can still listen and support you. How are you feeling?")
                    .suggestedFollowUps(List.of("Can you tell me more about that?", "How does that make you feel?"))
                    .aiAvailable(false)
                    .build();
            return fallback;
        }
    }
}
