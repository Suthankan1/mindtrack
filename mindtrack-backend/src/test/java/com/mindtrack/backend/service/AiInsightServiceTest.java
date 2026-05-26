package com.mindtrack.backend.service;

import com.mindtrack.backend.ai.GeminiService;
import com.mindtrack.backend.dto.JournalPromptRequest;
import com.mindtrack.backend.dto.JournalPromptResponse;
import com.mindtrack.backend.model.User;
import com.mindtrack.backend.model.UserPreference;
import com.mindtrack.backend.repository.MoodEntryRepository;
import com.mindtrack.backend.repository.UserPreferenceRepository;
import com.mindtrack.backend.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyDouble;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

/**
 * Unit tests for AiInsightService journal prompt privacy enforcement.
 *
 * <p>Verifies that {@code recentNoteSummaries} are stripped from the Gemini prompt
 * when the user has disabled {@code shareNotesWithAi} or {@code aiJournalAnalysisEnabled},
 * while structured mood metadata (moodScore, tags) are always preserved.
 */
class AiInsightServiceTest {

    private GeminiService geminiService;
    private UserPreferenceRepository userPreferenceRepository;
    private AiInsightService aiInsightService;
    private User testUser;

    @BeforeEach
    void setUp() {
        geminiService = mock(GeminiService.class);
        userPreferenceRepository = mock(UserPreferenceRepository.class);
        UserRepository userRepository = mock(UserRepository.class);
        MoodEntryRepository moodEntryRepository = mock(MoodEntryRepository.class);
        MoodPatternService moodPatternService = mock(MoodPatternService.class);
        JsonExtractionService jsonExtractionService = mock(JsonExtractionService.class);
        MentalHealthSafetyService mentalHealthSafetyService = mock(MentalHealthSafetyService.class);

        aiInsightService = new AiInsightService(
                userRepository,
                moodPatternService,
                moodEntryRepository,
                geminiService,
                new com.fasterxml.jackson.databind.ObjectMapper(),
                jsonExtractionService,
                mentalHealthSafetyService,
                userPreferenceRepository);

        testUser = User.builder()
                .email("test@example.com")
                .passwordHash("hash")
                .anonymousMode(false)
                .build();

        // Default: Gemini returns a valid JSON string so parsing doesn't fail with NPE
        when(geminiService.generateInsight(anyString(), anyString(), anyDouble()))
                .thenReturn("{\"promptTitle\":\"Test\",\"promptQuestion\":\"Q?\",\"followUpQuestions\":[\"a\",\"b\",\"c\"],\"estimatedMinutes\":3,\"tone\":\"Gentle\"}");

        // Default jsonExtractionService returns a basic response
        when(jsonExtractionService.extractAndParse(anyString(), eq(JournalPromptResponse.class)))
                .thenReturn(JournalPromptResponse.builder()
                        .promptTitle("Test")
                        .promptQuestion("Q?")
                        .followUpQuestions(List.of("a", "b", "c"))
                        .estimatedMinutes(3)
                        .tone("Gentle")
                        .aiAvailable(true)
                        .build());
    }

    // ─────────────────────────────────────────────────────────────────
    // Helper that builds a full UserPreference with explicit AI flags
    // ─────────────────────────────────────────────────────────────────

    private UserPreference buildPref(boolean shareNotes, boolean journalEnabled) {
        return UserPreference.builder()
                .themeMode("dark")
                .reminderEnabled(true)
                .reminderTime("20:00")
                .defaultCopingTechnique("Breathing")
                .privacyMode("standard")
                .aiJournalAnalysisEnabled(journalEnabled)
                .aiChatHistoryEnabled(true)
                .shareNotesWithAi(shareNotes)
                .build();
    }

    // ─────────────────────────────────────────────────────────────────
    // Test 1: Both flags enabled → note summaries reach Gemini
    // ─────────────────────────────────────────────────────────────────

    @Test
    void getJournalPrompt_bothAiFlagsEnabled_notesSentToGemini() {
        when(userPreferenceRepository.findByUser(testUser))
                .thenReturn(Optional.of(buildPref(true, true)));

        JournalPromptRequest request = JournalPromptRequest.builder()
                .moodScore(3)
                .tags(List.of("Work"))
                .recentNoteSummaries(List.of("Had a stressful meeting"))
                .build();

        aiInsightService.getJournalPrompt(request, testUser);

        ArgumentCaptor<String> promptCaptor = ArgumentCaptor.forClass(String.class);
        verify(geminiService).generateInsight(promptCaptor.capture(), anyString(), anyDouble());

        String sentPrompt = promptCaptor.getValue();
        assertThat(sentPrompt).contains("Had a stressful meeting");
        assertThat(sentPrompt).contains("Work");
    }

    // ─────────────────────────────────────────────────────────────────
    // Test 2: shareNotesWithAi = false → note summaries NOT sent to Gemini
    // ─────────────────────────────────────────────────────────────────

    @Test
    void getJournalPrompt_shareNotesWithAiDisabled_noteSummariesIgnored() {
        when(userPreferenceRepository.findByUser(testUser))
                .thenReturn(Optional.of(buildPref(false, true)));

        JournalPromptRequest request = JournalPromptRequest.builder()
                .moodScore(2)
                .tags(List.of("Sleep"))
                .recentNoteSummaries(List.of("Couldn't sleep, feeling anxious"))
                .build();

        aiInsightService.getJournalPrompt(request, testUser);

        ArgumentCaptor<String> promptCaptor = ArgumentCaptor.forClass(String.class);
        verify(geminiService).generateInsight(promptCaptor.capture(), anyString(), anyDouble());

        String sentPrompt = promptCaptor.getValue();
        // Note summaries must be absent
        assertThat(sentPrompt).doesNotContain("Couldn't sleep, feeling anxious");
        // Structured mood metadata must still be present
        assertThat(sentPrompt).contains("2");       // moodScore
        assertThat(sentPrompt).contains("Sleep");   // tag
    }

    // ─────────────────────────────────────────────────────────────────
    // Test 3: aiJournalAnalysisEnabled = false → note summaries NOT sent to Gemini
    // ─────────────────────────────────────────────────────────────────

    @Test
    void getJournalPrompt_aiJournalAnalysisDisabled_noteSummariesIgnored() {
        when(userPreferenceRepository.findByUser(testUser))
                .thenReturn(Optional.of(buildPref(true, false)));

        JournalPromptRequest request = JournalPromptRequest.builder()
                .moodScore(4)
                .tags(List.of("Exercise", "Social"))
                .recentNoteSummaries(List.of("Had a great run with friends"))
                .build();

        aiInsightService.getJournalPrompt(request, testUser);

        ArgumentCaptor<String> promptCaptor = ArgumentCaptor.forClass(String.class);
        verify(geminiService).generateInsight(promptCaptor.capture(), anyString(), anyDouble());

        String sentPrompt = promptCaptor.getValue();
        // Note summaries must be absent
        assertThat(sentPrompt).doesNotContain("Had a great run with friends");
        // Structured mood metadata must still be present
        assertThat(sentPrompt).contains("4");          // moodScore
        assertThat(sentPrompt).contains("Exercise");   // tag
        assertThat(sentPrompt).contains("Social");     // tag
    }
}
