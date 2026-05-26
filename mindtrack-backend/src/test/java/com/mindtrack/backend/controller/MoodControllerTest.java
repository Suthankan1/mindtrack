package com.mindtrack.backend.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.mindtrack.backend.dto.MoodLogRequest;
import com.mindtrack.backend.model.MoodEntry;
import com.mindtrack.backend.model.Streak;
import com.mindtrack.backend.model.StressPattern;
import com.mindtrack.backend.model.User;
import com.mindtrack.backend.repository.MoodEntryRepository;
import com.mindtrack.backend.repository.StreakRepository;
import com.mindtrack.backend.repository.StressPatternRepository;
import com.mindtrack.backend.repository.UserRepository;
import com.mindtrack.backend.service.MoodPatternService;
import com.mindtrack.backend.service.StreakService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
public class MoodControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private MoodEntryRepository moodEntryRepository;

    @Autowired
    private StreakRepository streakRepository;

    @Autowired
    private StressPatternRepository stressPatternRepository;

    @Autowired
    private StreakService streakService;

    @org.springframework.boot.test.mock.mockito.MockBean
    private com.mindtrack.backend.ai.GeminiService geminiService;

    @Autowired
    private MoodPatternService moodPatternService;

    @Autowired
    private ObjectMapper objectMapper;

    private User testUser;

    @BeforeEach
    void setUp() {
        // Clear all tables in child-to-parent order to prevent constraint violations
        stressPatternRepository.deleteAll();
        streakRepository.deleteAll();
        moodEntryRepository.deleteAll();
        userRepository.deleteAll();

        // Create a test user
        testUser = User.builder()
                .email("testuser@example.com")
                .passwordHash("passwordHash")
                .anonymousMode(false)
                .build();
        testUser = userRepository.save(testUser);
    }

    @Test
    @WithMockUser(username = "testuser@example.com")
    void logMood_Success() throws Exception {
        MoodLogRequest request = new MoodLogRequest();
        request.setMoodScore(4);
        request.setNote("Feeling good today!");
        request.setTags(List.of("Sleep", "Work"));

        mockMvc.perform(post("/api/mood/log")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id", notNullValue()))
                .andExpect(jsonPath("$.userId", is(testUser.getId().toString())))
                .andExpect(jsonPath("$.moodScore", is(4)))
                .andExpect(jsonPath("$.note", is("Feeling good today!")))
                .andExpect(jsonPath("$.tags", hasItems("Sleep", "Work")))
                .andExpect(jsonPath("$.timestamp", notNullValue()));

        // Verify Streak was initialized/updated
        Streak streak = streakService.getStreak(testUser);
        assertNotNull(streak);
        assertEquals(1, streak.getCurrentStreak());
        assertEquals(1, streak.getLongestStreak());
        assertEquals(LocalDate.now(), streak.getLastCheckInDate());
    }

    @Test
    @WithMockUser(username = "testuser@example.com")
    void logMood_ValidationError() throws Exception {
        MoodLogRequest request = new MoodLogRequest();
        request.setMoodScore(6); // Invalid score (must be 1-5)

        mockMvc.perform(post("/api/mood/log")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error", is("Validation Failed")))
                .andExpect(jsonPath("$.errors.moodScore", is("Mood score must be between 1 and 5")));
    }

    @Test
    @WithMockUser(username = "testuser@example.com")
    void logMood_TagValidationError() throws Exception {
        MoodLogRequest request = new MoodLogRequest();
        request.setMoodScore(4);
        request.setTags(List.of("Sleep", "HACK")); // "HACK" is not a valid tag

        mockMvc.perform(post("/api/mood/log")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error", is("Validation Failed")))
                .andExpect(jsonPath("$.errors.tagsValid", is("Tags must be one of: Sleep, Work, Exercise, Social, Mindfulness, Nutrition, Other")));
    }

    @Test
    @WithMockUser(username = "testuser@example.com")
    void logMood_TooManyTagsError() throws Exception {
        MoodLogRequest request = new MoodLogRequest();
        request.setMoodScore(4);
        request.setTags(List.of("Sleep", "Work", "Exercise", "Social", "Mindfulness", "Nutrition")); // 6 tags

        mockMvc.perform(post("/api/mood/log")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error", is("Validation Failed")))
                .andExpect(jsonPath("$.errors.tags", is("Maximum 5 tags per entry")));
    }

    @Test
    @WithMockUser(username = "testuser@example.com")
    void getTodayMoods_Success() throws Exception {
        // Create an entry logged today
        MoodEntry todayEntry = MoodEntry.builder()
                .user(testUser)
                .moodScore(3)
                .note("Decent day")
                .timestamp(LocalDateTime.now())
                .tags(List.of("calm"))
                .build();
        moodEntryRepository.save(todayEntry);

        // Create an entry logged yesterday
        MoodEntry yesterdayEntry = MoodEntry.builder()
                .user(testUser)
                .moodScore(5)
                .note("Awesome day")
                .timestamp(LocalDateTime.now().minusDays(1))
                .tags(List.of("joyful"))
                .build();
        moodEntryRepository.save(yesterdayEntry);

        mockMvc.perform(get("/api/mood/today"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(1)))
                .andExpect(jsonPath("$[0].moodScore", is(3)))
                .andExpect(jsonPath("$[0].note", is("Decent day")))
                .andExpect(jsonPath("$[0].tags[0]", is("calm")));
    }

    @Test
    @WithMockUser(username = "testuser@example.com")
    void getMoodHistory_Success() throws Exception {
        // Log entries spanning past few days
        for (int i = 0; i < 5; i++) {
            MoodEntry entry = MoodEntry.builder()
                    .user(testUser)
                    .moodScore(3 + (i % 3 - 1)) // scores: 2, 3, 4, 2, 3
                    .note("Day " + i)
                    .timestamp(LocalDateTime.now().minusDays(i))
                    .build();
            moodEntryRepository.save(entry);
        }

        mockMvc.perform(get("/api/mood/history").param("days", "10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(5)));
    }

    @Test
    void streakService_LogicVerification() {
        // Step 1: Initial streak update
        Streak streak1 = streakService.updateStreak(testUser);
        assertEquals(1, streak1.getCurrentStreak());
        assertEquals(1, streak1.getLongestStreak());
        assertEquals(LocalDate.now(), streak1.getLastCheckInDate());

        // Step 2: Update same day (streak shouldn't change)
        Streak streak2 = streakService.updateStreak(testUser);
        assertEquals(1, streak2.getCurrentStreak());
        assertEquals(1, streak2.getLongestStreak());

        // Step 3: Simulate check-in yesterday by modifying database record
        streak2.setLastCheckInDate(LocalDate.now().minusDays(1));
        streakRepository.save(streak2);

        // Check in today (streak should increment)
        Streak streak3 = streakService.updateStreak(testUser);
        assertEquals(2, streak3.getCurrentStreak());
        assertEquals(2, streak3.getLongestStreak());
        assertEquals(LocalDate.now(), streak3.getLastCheckInDate());

        // Step 4: Simulate broken streak by setting last check-in to 3 days ago
        streak3.setLastCheckInDate(LocalDate.now().minusDays(3));
        streakRepository.save(streak3);

        // Check in today (streak should reset to 1, longest remains 2)
        Streak streak4 = streakService.updateStreak(testUser);
        assertEquals(1, streak4.getCurrentStreak());
        assertEquals(2, streak4.getLongestStreak());
        assertEquals(LocalDate.now(), streak4.getLastCheckInDate());
    }

    @Test
    void moodPatternService_LogicVerification() {
        org.mockito.Mockito.when(geminiService.generateInsight(
                        org.mockito.Mockito.anyString(),
                        org.mockito.Mockito.any(),
                        org.mockito.Mockito.any()))
                .thenAnswer(invocation -> {
                    String prompt = invocation.getArgument(0);
                    if (prompt.contains("Average mood score: 3.0") || prompt.contains("Average mood score: 3,0")) {
                        return "Stable mood pattern. Continue tracking to see trends.";
                    } else if (prompt.contains("Average mood score: 1.5") || prompt.contains("Average mood score: 1,5")) {
                        return "High stress week detected";
                    } else if (prompt.contains("Average mood score: 4.5") || prompt.contains("Average mood score: 4,5")) {
                        return "Great week! Keep it up";
                    }
                    return "Mocked insight";
                });

        LocalDateTime now = LocalDateTime.now();

        // Save a mix of mood logs over the past week (average should be 3.0)
        moodEntryRepository.save(MoodEntry.builder().user(testUser).moodScore(2).timestamp(now.minusDays(1)).build());
        moodEntryRepository.save(MoodEntry.builder().user(testUser).moodScore(4).timestamp(now.minusDays(2)).build());
        moodEntryRepository.save(MoodEntry.builder().user(testUser).moodScore(3).timestamp(now.minusDays(3)).build());

        StressPattern pattern = moodPatternService.calculateWeeklyPattern(testUser, now.minusDays(7), now);
        assertNotNull(pattern);
        assertEquals(3.0, pattern.getWeeklyAverage(), 0.001);
        assertEquals("Stable mood pattern. Continue tracking to see trends.", pattern.getAiInsight());

        // Test high stress insight (< 2.5)
        moodEntryRepository.deleteAll();
        moodEntryRepository.save(MoodEntry.builder().user(testUser).moodScore(2).timestamp(now.minusDays(1)).build());
        moodEntryRepository.save(MoodEntry.builder().user(testUser).moodScore(1).timestamp(now.minusDays(2)).build());

        StressPattern stressPattern = moodPatternService.calculateWeeklyPattern(testUser, now.minusDays(7), now);
        assertEquals(1.5, stressPattern.getWeeklyAverage(), 0.001);
        assertEquals("High stress week detected", stressPattern.getAiInsight());

        // Test positive insight (> 3.5)
        moodEntryRepository.deleteAll();
        moodEntryRepository.save(MoodEntry.builder().user(testUser).moodScore(5).timestamp(now.minusDays(1)).build());
        moodEntryRepository.save(MoodEntry.builder().user(testUser).moodScore(4).timestamp(now.minusDays(2)).build());

        StressPattern happyPattern = moodPatternService.calculateWeeklyPattern(testUser, now.minusDays(7), now);
        assertEquals(4.5, happyPattern.getWeeklyAverage(), 0.001);
        assertEquals("Great week! Keep it up", happyPattern.getAiInsight());
    }

    @Test
    void moodPatternService_AiInsightValidationAndFallback() {
        LocalDateTime now = LocalDateTime.now();
        moodEntryRepository.save(MoodEntry.builder().user(testUser).moodScore(4).timestamp(now.minusDays(1)).build());
        moodEntryRepository.save(MoodEntry.builder().user(testUser).moodScore(4).timestamp(now.minusDays(2)).build());

        // Call 1: Valid insight
        org.mockito.Mockito.when(geminiService.generateInsight(
                        org.mockito.Mockito.anyString(),
                        org.mockito.Mockito.any(),
                        org.mockito.Mockito.any()))
                .thenReturn("This is a beautiful valid insight.");

        StressPattern pattern1 = moodPatternService.calculateWeeklyPattern(testUser, now.minusDays(7), now);
        assertNotNull(pattern1);
        assertEquals("This is a beautiful valid insight.", pattern1.getAiInsight());

        // Call 2: Error insight, should leave the previous valid insight intact
        org.mockito.Mockito.when(geminiService.generateInsight(
                        org.mockito.Mockito.anyString(),
                        org.mockito.Mockito.any(),
                        org.mockito.Mockito.any()))
                .thenReturn("Unable to generate AI insight due to error.");

        StressPattern pattern2 = moodPatternService.calculateWeeklyPattern(testUser, now.minusDays(7), now);
        assertNotNull(pattern2);
        // The id should be the same as it updates the existing pattern
        assertEquals(pattern1.getId(), pattern2.getId());
        assertEquals("This is a beautiful valid insight.", pattern2.getAiInsight());

        // Call 3: New pattern but with an error insight. Should set null instead of error message.
        // We delete the previous pattern to simulate a fresh pattern calculation.
        stressPatternRepository.deleteAll();

        StressPattern pattern3 = moodPatternService.calculateWeeklyPattern(testUser, now.minusDays(7), now);
        assertNotNull(pattern3);
        assertNull(pattern3.getAiInsight());
    }

    @Test
    @WithMockUser(username = "testuser@example.com")
    void logMood_CrisisRisk_FewerThanThreeDistinctDays() throws Exception {
        LocalDateTime now = LocalDateTime.now();
        // Log entries on only 2 distinct days (e.g., today and yesterday)
        moodEntryRepository.save(MoodEntry.builder().user(testUser).moodScore(1).timestamp(now.minusDays(1)).build());

        MoodLogRequest request = new MoodLogRequest();
        request.setMoodScore(1);
        request.setNote("Low mood");

        mockMvc.perform(post("/api/mood/log")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.crisisAlert", is(false)));
    }

    @Test
    @WithMockUser(username = "testuser@example.com")
    void logMood_CrisisRisk_ThreeDaysButOneDayMaxScoreGreaterThanTwo() throws Exception {
        LocalDateTime now = LocalDateTime.now();
        // Log entries on 2 distinct days: yesterday (score 3) and day before yesterday (score 1)
        moodEntryRepository.save(MoodEntry.builder().user(testUser).moodScore(3).timestamp(now.minusDays(1)).build());
        moodEntryRepository.save(MoodEntry.builder().user(testUser).moodScore(1).timestamp(now.minusDays(2)).build());

        // Log an entry today with score 1 (we now have entries on 3 distinct days: today (1), yesterday (3), day before yesterday (1))
        // Since yesterday's max score was 3 (which is > 2), this should NOT trigger a crisis alert.
        MoodLogRequest request = new MoodLogRequest();
        request.setMoodScore(1);
        request.setNote("Low mood");

        mockMvc.perform(post("/api/mood/log")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.crisisAlert", is(false)));
    }

    @Test
    @WithMockUser(username = "testuser@example.com")
    void logMood_CrisisRisk_ThreeDaysAllMaxScoresLessThanOrEqualToTwo() throws Exception {
        LocalDateTime now = LocalDateTime.now();
        // Mock Gemini service
        org.mockito.Mockito.when(geminiService.generateInsight(
                        org.mockito.Mockito.anyString(),
                        org.mockito.Mockito.any(),
                        org.mockito.Mockito.any()))
                .thenReturn("Compasionate AI crisis advice message.");

        // Log entries on 2 distinct days:
        // Yesterday: 2 entries, scores 1 and 2 (max is 2)
        // Day before yesterday: 1 entry, score 1 (max is 1)
        moodEntryRepository.save(MoodEntry.builder().user(testUser).moodScore(1).timestamp(now.minusDays(1)).build());
        moodEntryRepository.save(MoodEntry.builder().user(testUser).moodScore(2).timestamp(now.minusDays(1).minusHours(2)).build());
        moodEntryRepository.save(MoodEntry.builder().user(testUser).moodScore(1).timestamp(now.minusDays(2)).build());

        // Log an entry today with score 2 (we now have entries on 3 distinct days, all with max score <= 2)
        MoodLogRequest request = new MoodLogRequest();
        request.setMoodScore(2);
        request.setNote("Feeling down");

        mockMvc.perform(post("/api/mood/log")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.crisisAlert", is(true)))
                .andExpect(jsonPath("$.crisisMessage", is("Compasionate AI crisis advice message.")));
    }
}
