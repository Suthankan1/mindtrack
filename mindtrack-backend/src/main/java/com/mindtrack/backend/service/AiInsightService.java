package com.mindtrack.backend.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.mindtrack.backend.ai.GeminiService;
import com.mindtrack.backend.dto.*;
import com.mindtrack.backend.model.MoodEntry;
import com.mindtrack.backend.model.StressPattern;
import com.mindtrack.backend.model.User;
import com.mindtrack.backend.model.UserPreference;
import com.mindtrack.backend.repository.MoodEntryRepository;
import com.mindtrack.backend.repository.UserRepository;
import com.mindtrack.backend.repository.UserPreferenceRepository;
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
    private final MentalHealthSafetyService mentalHealthSafetyService;
    private final UserPreferenceRepository userPreferenceRepository;

    // Cache results by entryId (sentiment won't change for a saved note)
    private final Map<UUID, SentimentAnalysisResponse> sentimentCache = new ConcurrentHashMap<>();

    public AiInsightService(
            UserRepository userRepository,
            MoodPatternService moodPatternService,
            MoodEntryRepository moodEntryRepository,
            GeminiService geminiService,
            ObjectMapper objectMapper,
            JsonExtractionService jsonExtractionService,
            MentalHealthSafetyService mentalHealthSafetyService,
            UserPreferenceRepository userPreferenceRepository) {
        this.userRepository = userRepository;
        this.moodPatternService = moodPatternService;
        this.moodEntryRepository = moodEntryRepository;
        this.geminiService = geminiService;
        this.objectMapper = objectMapper;
        this.jsonExtractionService = jsonExtractionService;
        this.mentalHealthSafetyService = mentalHealthSafetyService;
        this.userPreferenceRepository = userPreferenceRepository;
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
     * Analyzes the last 30 days of mood entries for the user to detect anomalies and burnout trends.
     */
    public MoodAnomalyResponse getMoodAnomaly(User user) {
        LocalDateTime end = LocalDateTime.now();
        LocalDateTime start = end.minusDays(30);

        List<MoodEntry> entries = moodEntryRepository.findByUserAndTimestampAfterOrderByTimestampDesc(user, start);

        if (entries.size() < 5) {
            return MoodAnomalyResponse.builder()
                    .riskLevel("LOW")
                    .detectedPatterns(Collections.emptyList())
                    .suggestedAction("Log at least 5 mood entries to activate the Anomaly Radar.")
                    .supportiveInsight("We need a few more logs to understand your personal baseline and detect subtle shifts.")
                    .confidence(0.0)
                    .insufficientData(true)
                    .build();
        }

        // Chronological order (oldest to newest)
        List<MoodEntry> chronological = new ArrayList<>(entries);
        chronological.sort(Comparator.comparing(MoodEntry::getTimestamp));

        List<String> patterns = new ArrayList<>();

        // 1. Sudden drop from personal baseline
        // entries are DESC (newest first): compare newest quarter against oldest half
        int recentCount = Math.min(3, entries.size() / 4 + 1);
        int olderStart = entries.size() / 2;
        List<MoodEntry> recent = entries.subList(0, recentCount);
        List<MoodEntry> older = entries.size() > olderStart
            ? entries.subList(olderStart, entries.size())
            : entries.subList(recentCount, entries.size());

        double recentAvg = recent.stream().mapToInt(MoodEntry::getMoodScore).average().orElse(0.0);
        double olderAvg = older.stream().mapToInt(MoodEntry::getMoodScore).average().orElse(0.0);

        if (recentAvg <= olderAvg - 1.0) {
            patterns.add("Sudden mood drop from personal baseline");
        }

        // 2. 3-day downward trend
        boolean hasDownwardTrend = false;
        for (int i = 2; i < chronological.size(); i++) {
            int s1 = chronological.get(i - 2).getMoodScore();
            int s2 = chronological.get(i - 1).getMoodScore();
            int s3 = chronological.get(i).getMoodScore();
            if (s3 < s2 && s2 < s1) {
                hasDownwardTrend = true;
                break;
            }
        }
        if (hasDownwardTrend) {
            patterns.add("3-day continuous downward trend");
        }

        // 3. Repeated low mood on same weekdays
        Map<java.time.DayOfWeek, List<Integer>> weekdayScores = new HashMap<>();
        for (MoodEntry e : entries) {
            java.time.DayOfWeek day = e.getTimestamp().getDayOfWeek();
            weekdayScores.computeIfAbsent(day, k -> new ArrayList<>()).add(e.getMoodScore());
        }
        List<String> repeatedLowWeekdays = new ArrayList<>();
        for (Map.Entry<java.time.DayOfWeek, List<Integer>> entry : weekdayScores.entrySet()) {
            long lowCount = entry.getValue().stream().filter(score -> score <= 2).count();
            if (lowCount >= 2) {
                repeatedLowWeekdays.add(entry.getKey().name());
            }
        }
        if (!repeatedLowWeekdays.isEmpty()) {
            patterns.add("Repeated low mood on " + String.join(", ", repeatedLowWeekdays));
        }

        // 4. Work/sleep tag correlation with low scores
        double overallAvg = entries.stream().mapToInt(MoodEntry::getMoodScore).average().orElse(0.0);
        List<MoodEntry> workEntries = entries.stream()
                .filter(e -> e.getTags() != null && e.getTags().stream().anyMatch(t -> t.equalsIgnoreCase("Work")))
                .toList();
        List<MoodEntry> sleepEntries = entries.stream()
                .filter(e -> e.getTags() != null && e.getTags().stream().anyMatch(t -> t.equalsIgnoreCase("Sleep")))
                .toList();

        if (workEntries.size() >= 2) {
            double workAvg = workEntries.stream().mapToInt(MoodEntry::getMoodScore).average().orElse(0.0);
            if (workAvg <= 2.2 || workAvg <= overallAvg - 0.8) {
                patterns.add("Low mood strongly correlated with 'Work' activity");
            }
        }

        if (sleepEntries.size() >= 2) {
            double sleepAvg = sleepEntries.stream().mapToInt(MoodEntry::getMoodScore).average().orElse(0.0);
            if (sleepAvg <= 2.2 || sleepAvg <= overallAvg - 0.8) {
                patterns.add("Low mood strongly correlated with 'Sleep' quality");
            }
        }

        // Risk level classification
        String riskLevel = "LOW";
        double confidence = 0.9;
        if (patterns.size() >= 3) {
            riskLevel = "HIGH";
            confidence = 0.85;
        } else if (patterns.size() > 0) {
            riskLevel = "MEDIUM";
            confidence = 0.8;
        }

        // Prepare prompt for Gemini
        String patternsText = patterns.isEmpty() ? "No severe burnout anomalies detected." : String.join(", ", patterns);
        String workStatsText = workEntries.isEmpty() ? "No entries tagged with 'Work'." : String.format("%d 'Work' logs (avg: %.1f)", workEntries.size(), workEntries.stream().mapToInt(MoodEntry::getMoodScore).average().orElse(0.0));
        String sleepStatsText = sleepEntries.isEmpty() ? "No entries tagged with 'Sleep'." : String.format("%d 'Sleep' logs (avg: %.1f)", sleepEntries.size(), sleepEntries.stream().mapToInt(MoodEntry::getMoodScore).average().orElse(0.0));

        String prompt = String.format("""
        You are an empathetic, compassionate mental health companion inside the MindTrack app.
        Analyze this user's mood anomaly telemetry from the past 30 days and provide a warm, non-clinical phrasing of the insights.

        Total entries analyzed: %d logs
        Average mood score: %.1f / 5.0
        Detected anomaly patterns: %s
        Work tag stats: %s
        Sleep tag stats: %s
        Calculated Risk Level: %s

        Respond ONLY with valid JSON in this exact format (no markdown, no other text):
        {
          "supportiveInsight": "two compassionate, supportive sentences describing what the radar shows and acknowledging their energetic baseline",
          "suggestedAction": "one warm, highly actionable suggestion (e.g. taking a specific breathing exercise, setting calendar boundaries, or checking sleep hygiene)"
        }
        """, entries.size(), overallAvg, patternsText, workStatsText, sleepStatsText, riskLevel);

        try {
            String rawResponse = geminiService.generateInsight(prompt, "application/json", 0.2);
            MoodAnomalyResponse parsed = jsonExtractionService.extractAndParse(rawResponse, MoodAnomalyResponse.class);
            parsed.setRiskLevel(riskLevel);
            parsed.setDetectedPatterns(patterns);
            parsed.setConfidence(confidence);
            parsed.setInsufficientData(false);
            return parsed;
        } catch (Exception e) {
            log.error("Failed to generate and parse Gemini anomaly response: {}", e.getMessage());

            // Build local supportive insights and actions based on statistics
            String supportiveInsight = "We noticed a stable emotional baseline over the last month. Keep tracking your daily mood to help monitor your wellness trends.";
            String suggestedAction = "Take a moment for a deep, slow breath to ground yourself.";

            if (riskLevel.equals("HIGH")) {
                supportiveInsight = "Your recent mood telemetry shows a significant drop and repeated patterns of low mood. We are here to support you through this challenging period.";
                suggestedAction = "Consider setting gentle calendar boundaries today and practicing box breathing.";
            } else if (riskLevel.equals("MEDIUM")) {
                supportiveInsight = "We detected minor downward trends or specific workday triggers. Paying close attention to your energy shifts can help you find balance.";
                suggestedAction = "Try a 5-minute deep breathing session to restore your clarity.";
            }

            return MoodAnomalyResponse.builder()
                    .riskLevel(riskLevel)
                    .detectedPatterns(patterns)
                    .suggestedAction(suggestedAction)
                    .supportiveInsight(supportiveInsight)
                    .confidence(confidence)
                    .insufficientData(false)
                    .build();
        }
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

        UserPreference pref = userPreferenceRepository.findByUser(user)
                .orElseGet(() -> UserPreference.builder()
                        .themeMode("dark")
                        .reminderEnabled(true)
                        .reminderTime("20:00")
                        .defaultCopingTechnique("Breathing")
                        .privacyMode("standard")
                        .aiJournalAnalysisEnabled(false)
                        .aiChatHistoryEnabled(false)
                        .shareNotesWithAi(false)
                        .build());

        if (!pref.isAiJournalAnalysisEnabled() || !pref.isShareNotesWithAi()) {
            return SentimentAnalysisResponse.builder()
                    .sentiment("neutral")
                    .emotionalTone("uncertain")
                    .themes(Collections.emptyList())
                    .confidence(0.0)
                    .supportMessage("AI journal analysis is disabled in your privacy settings.")
                    .aiAvailable(false)
                    .build();
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
        You are a compassionate mental wellness companion. A user has been experiencing
        consistently low mood (score 1-2 out of 5) for 3 or more days.

        Write a short, warm, non-clinical message that:
        1. Acknowledges that they are going through a difficult time without diagnosing them or labeling their condition.
        2. Reminds them they are not alone and that support is always available.
        3. Encourages seeking immediate local emergency support or calling a crisis helpline if they are in imminent danger.
        4. Clearly indicates that MindTrack is an automated companion and cannot monitor, screen, or respond to emergencies in real-time.
        5. Does NOT use clinical terminology, does NOT pretend the app is monitoring them, and is supportive and hopeful.

        Maximum 4 sentences. Tone: supportive, non-clinical, and aligned with SDG 3.
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
    public ChatResponse chatWithAi(ChatRequest request, User user) {
        // Check for safety / high-risk words
        if (mentalHealthSafetyService.isHighRisk(request.getMessage())) {
            log.warn("High-risk safety keyword detected in user chat message. Intercepting and returning crisis resources.");
            return ChatResponse.builder()
                    .reply(mentalHealthSafetyService.getCrisisSafeMessage())
                    .suggestedFollowUps(List.of("Can I try box breathing?", "Show me some coping suggestions."))
                    .showCrisisResources(true)
                    .crisisResources(mentalHealthSafetyService.getCrisisResources())
                    .aiAvailable(true)
                    .build();
        }

        UserPreference pref = null;
        if (user != null) {
            pref = userPreferenceRepository.findByUser(user)
                    .orElseGet(() -> UserPreference.builder()
                            .themeMode("dark")
                            .reminderEnabled(true)
                            .reminderTime("20:00")
                            .defaultCopingTechnique("Breathing")
                            .privacyMode("standard")
                            .aiJournalAnalysisEnabled(false)
                            .aiChatHistoryEnabled(false)
                            .shareNotesWithAi(false)
                            .build());
        }

        final UserPreference finalPref = pref != null ? pref : UserPreference.builder()
                .themeMode("dark")
                .reminderEnabled(true)
                .reminderTime("20:00")
                .defaultCopingTechnique("Breathing")
                .privacyMode("standard")
                .aiJournalAnalysisEnabled(false)
                .aiChatHistoryEnabled(false)
                .shareNotesWithAi(false)
                .build();

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
        if (finalPref.isAiChatHistoryEnabled() && request.getConversationHistory() != null) {
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

    /**
     * Generates a personalized journal reflection prompt using Gemini based on mood and tags.
     * Falls back to a high-fidelity local prompt library if the Gemini API fails or is offline.
     */
    public JournalPromptResponse getJournalPrompt(JournalPromptRequest request, User user) {
        UserPreference pref = null;
        if (user != null) {
            pref = userPreferenceRepository.findByUser(user)
                    .orElseGet(() -> UserPreference.builder()
                            .themeMode("dark")
                            .reminderEnabled(true)
                            .reminderTime("20:00")
                            .defaultCopingTechnique("Breathing")
                            .privacyMode("standard")
                            .aiJournalAnalysisEnabled(false)
                            .aiChatHistoryEnabled(false)
                            .shareNotesWithAi(false)
                            .build());
        }

        final UserPreference finalPref = pref != null ? pref : UserPreference.builder()
                .themeMode("dark")
                .reminderEnabled(true)
                .reminderTime("20:00")
                .defaultCopingTechnique("Breathing")
                .privacyMode("standard")
                .aiJournalAnalysisEnabled(false)
                .aiChatHistoryEnabled(false)
                .shareNotesWithAi(false)
                .build();

        String moodDescriptor = getMoodDescriptor(request.getMoodScore());
        String tagsText = (request.getTags() == null || request.getTags().isEmpty()) ? "None" : String.join(", ", request.getTags());
        
        List<String> summaries = request.getRecentNoteSummaries();
        if (!finalPref.isShareNotesWithAi() || !finalPref.isAiJournalAnalysisEnabled()) {
            summaries = Collections.emptyList();
        }
        String summariesText = (summaries == null || summaries.isEmpty()) ? "None" : String.join("; ", summaries);

        String prompt = String.format("""
        You are a warm, highly compassionate mental health companion inside the MindTrack app.
        Generate a deeply personalized, empathetic journal reflection prompt tailored to this user's current mood and activities.
        
        Current Mood: %d / 5 (%s)
        Active Tags (associated activities/contexts): %s
        Optional Recent Note Summaries: %s
        
        Using this context, craft a beautiful reflection prompt that helps them process their feelings.
        
        Respond ONLY with a valid JSON object in this exact format (no markdown, no other text):
        {
          "promptTitle": "A creative, comforting title (maximum 4 words)",
          "promptQuestion": "One deep, open-ended reflection question tailored directly to their mood and active tags",
          "followUpQuestions": [
            "first gentle follow-up question",
            "second gentle follow-up question",
            "third gentle follow-up question"
          ],
          "estimatedMinutes": 3,
          "tone": "a descriptive word for the emotional tone (e.g. Grounding, Vibrant, Restorative, Gentle, Observant)"
        }
        """, request.getMoodScore(), moodDescriptor, tagsText, summariesText);

        try {
            String rawResponse = geminiService.generateInsight(prompt, "application/json", 0.7);
            JournalPromptResponse parsed = jsonExtractionService.extractAndParse(rawResponse, JournalPromptResponse.class);
            parsed.setAiAvailable(true);
            return parsed;
        } catch (Exception e) {
            log.error("Failed to generate and parse Gemini journal prompt response: {}", e.getMessage());
            return getFallbackPrompt(request.getMoodScore());
        }
    }

    private String getMoodDescriptor(int score) {
        return switch (score) {
            case 1 -> "High Stress";
            case 2 -> "Low Energy";
            case 3 -> "Neutral";
            case 4 -> "Stable";
            case 5 -> "Radiant";
            default -> "Neutral";
        };
    }

    private JournalPromptResponse getFallbackPrompt(int score) {
        JournalPromptResponse fallback = new JournalPromptResponse();
        fallback.setAiAvailable(false);

        switch (score) {
            case 1 -> {
                fallback.setPromptTitle("Calming the Storm");
                fallback.setPromptQuestion("What is currently demanding the most energy from you, and how can you take one step back to breathe?");
                fallback.setFollowUpQuestions(List.of(
                    "Where do you feel this tension in your body?",
                    "What is one thing you can say 'no' to today?",
                    "Who is someone you can lean on for support?"
                ));
                fallback.setEstimatedMinutes(3);
                fallback.setTone("Empathetic and grounding");
            }
            case 2 -> {
                fallback.setPromptTitle("Gentle Refueling");
                fallback.setPromptQuestion("When your energy is low, what is the smallest, most comforting thing you can do for yourself right now?");
                fallback.setFollowUpQuestions(List.of(
                    "How has your sleep or rest been lately?",
                    "What is a gentle activity that usually restores you?",
                    "How can you show yourself kindness today?"
                ));
                fallback.setEstimatedMinutes(3);
                fallback.setTone("Soft and supportive");
            }
            case 4 -> {
                fallback.setPromptTitle("Anchoring the Good");
                fallback.setPromptQuestion("What brought a sense of peace, accomplishment, or quiet joy to your day, even if it was tiny?");
                fallback.setFollowUpQuestions(List.of(
                    "How can you carry this pleasant feeling into tomorrow?",
                    "What activity contributed most to this stable mood?",
                    "What are you feeling grateful for right now?"
                ));
                fallback.setEstimatedMinutes(5);
                fallback.setTone("Warm and appreciative");
            }
            case 5 -> {
                fallback.setPromptTitle("Celebrating Clarity");
                fallback.setPromptQuestion("Your energy feels radiant today. What is flowing well in your life right now that you want to celebrate?");
                fallback.setFollowUpQuestions(List.of(
                    "How can you capture and remember this feeling of expansion?",
                    "How can you share this positive energy with others?",
                    "What dreams or hopes feel closest to you today?"
                ));
                fallback.setEstimatedMinutes(5);
                fallback.setTone("Uplifting and vibrant");
            }
            default -> {
                fallback.setPromptTitle("Checking In");
                fallback.setPromptQuestion("How would you describe the transition of your energy today from morning until this very moment?");
                fallback.setFollowUpQuestions(List.of(
                    "What felt stable or balanced today?",
                    "Is there any subtle emotion waiting to be noticed?",
                    "What is one word that sums up your current state?"
                ));
                fallback.setEstimatedMinutes(5);
                fallback.setTone("Mindful and observant");
            }
        }
        return fallback;
    }

    /**
     * Generates a personalized instant AI reflection after mood logging using Gemini.
     * Falls back to a deterministic, high-fidelity message library if Gemini fails.
     */
    public MoodReflectionResponse getMoodReflection(MoodReflectionRequest request, User user) {
        int score = request.getMoodScore();
        List<String> tags = request.getTags();
        if (tags == null) {
            tags = Collections.emptyList();
        }
        String note = request.getNote();
        if (note == null) {
            note = "";
        }

        UserPreference pref = userPreferenceRepository.findByUser(user)
                .orElseGet(() -> UserPreference.builder()
                        .themeMode("dark")
                        .reminderEnabled(true)
                        .reminderTime("20:00")
                        .defaultCopingTechnique("Breathing")
                        .privacyMode("standard")
                        .aiJournalAnalysisEnabled(false)
                        .aiChatHistoryEnabled(false)
                        .shareNotesWithAi(false)
                        .build());

        if (!pref.isAiJournalAnalysisEnabled() || !pref.isShareNotesWithAi()) {
            note = "";
        }

        // 1. Calculate recent average if null
        double recentAverage = request.getRecentAverage() != null ? request.getRecentAverage() : 3.0;
        if (request.getRecentAverage() == null) {
            LocalDateTime start = LocalDateTime.now().minusDays(7);
            List<MoodEntry> recentEntries = moodEntryRepository.findByUserAndTimestampAfterOrderByTimestampDesc(user, start);
            if (!recentEntries.isEmpty()) {
                recentAverage = recentEntries.stream().mapToInt(MoodEntry::getMoodScore).average().orElse(3.0);
            }
        }

        // 2. Scan note/tags for high-risk words using MentalHealthSafetyService
        boolean hasHighRiskText = mentalHealthSafetyService.isHighRisk(note);
        boolean showCrisisResources = score <= 1 || hasHighRiskText;

        // 3. Assemble prompt for Gemini
        String tagsText = tags.isEmpty() ? "None" : String.join(", ", tags);
        String recentAverageText = String.format("%.1f", recentAverage);

        String prompt = String.format("""
        You are an empathetic, compassionate mental health companion inside the MindTrack app.
        A user has just logged their mood check-in. Provide a brief, supportive, and validated instant reflection.

        User Mood Score: %d / 5 (1=critical stress/crisis, 5=excellent/radiant)
        Active Tags (associated activities/contexts): %s
        Optional Reflection Note: "%s"
        Recent 7-day Average Mood: %s

        Choose the SINGLE best recommended coping technique for right now from this list:
        - breathing_478 (best for acute anxiety, panic, or critical stress)
        - breathing_box (best for stress, focus, and centering)
        - breathing_deep (best for general physical tension and calming down)
        - grounding (best for overwhelm, racing thoughts, or dissociation)
        - journaling (best for processing thoughts, neutral or complex feelings)
        - walk (best for low energy, stagnation, or positive reflection outdoors)

        Respond ONLY with a valid JSON object in this exact format (no markdown, no other text):
        {
          "oneSentenceReflection": "a single, short, empathetic, validating sentence acknowledging their state without diagnostic labels",
          "suggestedNextStep": "one concise, gentle, actionable suggestion (e.g. taking a slow breath, stepping outside, or resting)",
          "recommendedTechnique": "one of the technique IDs from the list",
          "showCrisisResources": %b
        }
        """, score, tagsText, note, recentAverageText, showCrisisResources);

        try {
            String rawResponse = geminiService.generateInsight(prompt, "application/json", 0.3);
            MoodReflectionResponse parsed = jsonExtractionService.extractAndParse(rawResponse, MoodReflectionResponse.class);
            parsed.setAiAvailable(true);
            // Ensure showCrisisResources is true if calculated as high risk
            if (showCrisisResources) {
                parsed.setShowCrisisResources(true);
            }
            return parsed;
        } catch (Exception e) {
            log.error("Failed to generate and parse Gemini mood reflection: {}", e.getMessage());
            return getFallbackReflection(score, showCrisisResources);
        }
    }

    private MoodReflectionResponse getFallbackReflection(int score, boolean showCrisisResources) {
        MoodReflectionResponse fallback = new MoodReflectionResponse();
        fallback.setAiAvailable(false);
        fallback.setShowCrisisResources(showCrisisResources);

        switch (score) {
            case 1 -> {
                fallback.setOneSentenceReflection("It sounds like you're carrying a heavy burden right now. Please be gentle with yourself.");
                fallback.setSuggestedNextStep("Try a quick grounding exercise or reach out to a trusted loved one.");
                fallback.setRecommendedTechnique("grounding");
            }
            case 2 -> {
                fallback.setOneSentenceReflection("Your energy is feeling a bit low today, and that is completely okay.");
                fallback.setSuggestedNextStep("Give yourself permission to rest or engage in a gentle activity.");
                fallback.setRecommendedTechnique("breathing_deep");
            }
            case 4 -> {
                fallback.setOneSentenceReflection("It's wonderful to feel a sense of stable peace in your day.");
                fallback.setSuggestedNextStep("Take a moment to appreciate this stable energy and keep doing what supports you.");
                fallback.setRecommendedTechnique("walk");
            }
            case 5 -> {
                fallback.setOneSentenceReflection("Your spirit is shining bright today! Enjoy this wonderful feeling.");
                fallback.setSuggestedNextStep("Share your joy or anchor this moment in a quick journal entry.");
                fallback.setRecommendedTechnique("journaling");
            }
            default -> { // Case 3 (neutral)
                fallback.setOneSentenceReflection("You're feeling centered and balanced today.");
                fallback.setSuggestedNextStep("Continue observing your day with gentle mindfulness.");
                fallback.setRecommendedTechnique("journaling");
            }
        }
        return fallback;
    }
}
