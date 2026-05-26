package com.mindtrack.backend.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.mindtrack.backend.dto.ChangePasswordRequest;
import com.mindtrack.backend.model.User;
import com.mindtrack.backend.repository.UserRepository;
import com.mindtrack.backend.repository.UserPreferenceRepository;
import com.mindtrack.backend.repository.MoodEntryRepository;
import com.mindtrack.backend.repository.CopingSessionRepository;
import com.mindtrack.backend.repository.StreakRepository;
import com.mindtrack.backend.repository.StressPatternRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.hamcrest.Matchers.is;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import org.springframework.boot.test.mock.mockito.MockBean;
import com.mindtrack.backend.service.AiInsightService;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
public class UserControllerTest {

    @MockBean
    private AiInsightService aiInsightService;

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private UserPreferenceRepository userPreferenceRepository;

    @Autowired
    private MoodEntryRepository moodEntryRepository;

    @Autowired
    private CopingSessionRepository copingSessionRepository;

    @Autowired
    private StreakRepository streakRepository;

    @Autowired
    private StressPatternRepository stressPatternRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private ObjectMapper objectMapper;

    private User testUser;

    @BeforeEach
    void setUp() {
        userPreferenceRepository.deleteAll();
        stressPatternRepository.deleteAll();
        streakRepository.deleteAll();
        moodEntryRepository.deleteAll();
        copingSessionRepository.deleteAll();
        userRepository.deleteAll();

        testUser = User.builder()
                .email("testuser@example.com")
                .passwordHash(passwordEncoder.encode("oldPassword123"))
                .anonymousMode(false)
                .build();
        testUser = userRepository.save(testUser);
    }

    @Test
    @WithMockUser(username = "testuser@example.com")
    void changePassword_Success() throws Exception {
        ChangePasswordRequest request = ChangePasswordRequest.builder()
                .currentPassword("oldPassword123")
                .newPassword("newSecurePassword456")
                .build();

        mockMvc.perform(post("/api/user/change-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message", is("Password updated successfully.")));

        User updatedUser = userRepository.findByEmail("testuser@example.com")
                .orElseThrow(() -> new AssertionError("Expected user not found"));
        assertTrue(passwordEncoder.matches("newSecurePassword456", updatedUser.getPasswordHash()));
    }

    @Test
    @WithMockUser(username = "testuser@example.com")
    void changePassword_WrongCurrentPassword() throws Exception {
        ChangePasswordRequest request = ChangePasswordRequest.builder()
                .currentPassword("wrongCurrentPassword")
                .newPassword("newSecurePassword456")
                .build();

        mockMvc.perform(post("/api/user/change-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", is("Current password is incorrect.")));

        User updatedUser = userRepository.findByEmail("testuser@example.com")
                .orElseThrow(() -> new AssertionError("Expected user not found"));
        assertTrue(passwordEncoder.matches("oldPassword123", updatedUser.getPasswordHash()));
    }

    @Test
    @WithMockUser(username = "testuser@example.com")
    void changePassword_WeakNewPassword() throws Exception {
        ChangePasswordRequest request = ChangePasswordRequest.builder()
                .currentPassword("oldPassword123")
                .newPassword("weak7")
                .build();

        mockMvc.perform(post("/api/user/change-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error", is("Validation Failed")))
                .andExpect(jsonPath("$.errors.newPassword", is("New password must be at least 8 characters")));
    }

    @Test
    @WithMockUser(username = "testuser@example.com")
    void changePassword_SamePassword() throws Exception {
        ChangePasswordRequest request = ChangePasswordRequest.builder()
                .currentPassword("oldPassword123")
                .newPassword("oldPassword123")
                .build();

        mockMvc.perform(post("/api/user/change-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", is("New password cannot be the same as the current password.")));
    }

    @Test
    void changePassword_Unauthenticated() throws Exception {
        ChangePasswordRequest request = ChangePasswordRequest.builder()
                .currentPassword("oldPassword123")
                .newPassword("newSecurePassword456")
                .build();

        mockMvc.perform(post("/api/user/change-password")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isForbidden());
    }

    @Test
    @WithMockUser(username = "testuser@example.com")
    void getPreferences_Success_CreatesDefault() throws Exception {
        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get("/api/user/preferences"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.themeMode", is("dark")))
                .andExpect(jsonPath("$.reminderEnabled", is(true)))
                .andExpect(jsonPath("$.reminderTime", is("20:00")))
                .andExpect(jsonPath("$.defaultCopingTechnique", is("Breathing")))
                .andExpect(jsonPath("$.privacyMode", is("standard")))
                .andExpect(jsonPath("$.aiJournalAnalysisEnabled", is(true)))
                .andExpect(jsonPath("$.aiChatHistoryEnabled", is(false)))
                .andExpect(jsonPath("$.shareNotesWithAi", is(false)));
    }

    @Test
    @WithMockUser(username = "testuser@example.com")
    void updatePreferences_Success() throws Exception {
        com.mindtrack.backend.dto.UserPreferenceDto updateDto = com.mindtrack.backend.dto.UserPreferenceDto.builder()
                .themeMode("light")
                .reminderEnabled(false)
                .reminderTime("08:00")
                .defaultCopingTechnique("Journaling")
                .privacyMode("strict")
                .aiJournalAnalysisEnabled(true)
                .aiChatHistoryEnabled(true)
                .shareNotesWithAi(true)
                .build();

        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put("/api/user/preferences")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(updateDto)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.themeMode", is("light")))
                .andExpect(jsonPath("$.reminderEnabled", is(false)))
                .andExpect(jsonPath("$.reminderTime", is("08:00")))
                .andExpect(jsonPath("$.defaultCopingTechnique", is("Journaling")))
                .andExpect(jsonPath("$.privacyMode", is("strict")))
                .andExpect(jsonPath("$.aiJournalAnalysisEnabled", is(true)))
                .andExpect(jsonPath("$.aiChatHistoryEnabled", is(true)))
                .andExpect(jsonPath("$.shareNotesWithAi", is(true)));
    }

    @Test
    void getPreferences_Unauthenticated() throws Exception {
        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get("/api/user/preferences"))
                .andExpect(status().isForbidden());
    }

    @Test
    @WithMockUser(username = "testuser@example.com")
    void getWellnessPassport_Success() throws Exception {
        // Mock weekly insight and anomaly responses
        org.mockito.Mockito.when(aiInsightService.getWeeklyInsight(org.mockito.ArgumentMatchers.any(User.class)))
                .thenReturn(java.util.Map.of("insight", "Mocked AI Weekly Insight"));

        com.mindtrack.backend.dto.MoodAnomalyResponse anomalyResponse = com.mindtrack.backend.dto.MoodAnomalyResponse.builder()
                .riskLevel("LOW")
                .detectedPatterns(java.util.Collections.emptyList())
                .suggestedAction("Take a deep breath.")
                .supportiveInsight("Mocked anomaly insight")
                .confidence(0.9)
                .insufficientData(false)
                .build();
        org.mockito.Mockito.when(aiInsightService.getMoodAnomaly(org.mockito.ArgumentMatchers.any(User.class)))
                .thenReturn(anomalyResponse);

        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get("/api/user/wellness-passport"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.averageMood").exists())
                .andExpect(jsonPath("$.streak").exists())
                .andExpect(jsonPath("$.topTags").isArray())
                .andExpect(jsonPath("$.copingSessionsCompleted").exists())
                .andExpect(jsonPath("$.aiWeeklyInsight", is("Mocked AI Weekly Insight")))
                .andExpect(jsonPath("$.anomalyRadarResult.riskLevel", is("LOW")));
    }

    @Test
    void getWellnessPassport_Unauthenticated() throws Exception {
        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get("/api/user/wellness-passport"))
                .andExpect(status().isForbidden());
    }

    @Test
    @WithMockUser(username = "testuser@example.com")
    void updatePreferences_InvalidThemeMode() throws Exception {
        com.mindtrack.backend.dto.UserPreferenceDto updateDto = com.mindtrack.backend.dto.UserPreferenceDto.builder()
                .themeMode("invalid_theme")
                .build();

        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put("/api/user/preferences")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(updateDto)))
                .andExpect(status().isBadRequest());
    }

    @Test
    @WithMockUser(username = "testuser@example.com")
    void updatePreferences_InvalidPrivacyMode() throws Exception {
        com.mindtrack.backend.dto.UserPreferenceDto updateDto = com.mindtrack.backend.dto.UserPreferenceDto.builder()
                .privacyMode("invalid_privacy")
                .build();

        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put("/api/user/preferences")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(updateDto)))
                .andExpect(status().isBadRequest());
    }

    @Test
    @WithMockUser(username = "testuser@example.com")
    void updatePreferences_InvalidReminderTime() throws Exception {
        com.mindtrack.backend.dto.UserPreferenceDto updateDto1 = com.mindtrack.backend.dto.UserPreferenceDto.builder()
                .reminderTime("25:00") // invalid hour
                .build();

        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put("/api/user/preferences")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(updateDto1)))
                .andExpect(status().isBadRequest());

        com.mindtrack.backend.dto.UserPreferenceDto updateDto2 = com.mindtrack.backend.dto.UserPreferenceDto.builder()
                .reminderTime("9:30") // invalid format (no leading zero)
                .build();

        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put("/api/user/preferences")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(updateDto2)))
                .andExpect(status().isBadRequest());
    }

    @Test
    @WithMockUser(username = "testuser@example.com")
    void updatePreferences_PartialUpdate() throws Exception {
        // First get default preferences to initialize them
        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get("/api/user/preferences"))
                .andExpect(status().isOk());

        // Perform partial update
        com.mindtrack.backend.dto.UserPreferenceDto updateDto = com.mindtrack.backend.dto.UserPreferenceDto.builder()
                .themeMode("light")
                .build();

        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put("/api/user/preferences")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(updateDto)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.themeMode", is("light")))
                // Ensure other fields are preserved and not set to null or default
                .andExpect(jsonPath("$.reminderEnabled", is(true)))
                .andExpect(jsonPath("$.reminderTime", is("20:00")))
                .andExpect(jsonPath("$.defaultCopingTechnique", is("Breathing")))
                .andExpect(jsonPath("$.privacyMode", is("standard")));
    }

    @Test
    @WithMockUser(username = "testuser@example.com")
    void clearUserData_Success() throws Exception {
        // Seed some data
        moodEntryRepository.save(com.mindtrack.backend.model.MoodEntry.builder()
                .user(testUser)
                .moodScore(4)
                .note("Logging standard data")
                .timestamp(java.time.LocalDateTime.now())
                .build());

        copingSessionRepository.save(com.mindtrack.backend.model.CopingSession.builder()
                .user(testUser)
                .type("Breathing")
                .durationSeconds(120)
                .completedAt(java.time.LocalDateTime.now())
                .build());

        streakRepository.save(com.mindtrack.backend.model.Streak.builder()
                .user(testUser)
                .currentStreak(3)
                .longestStreak(5)
                .lastCheckInDate(java.time.LocalDate.now())
                .build());

        stressPatternRepository.save(com.mindtrack.backend.model.StressPattern.builder()
                .user(testUser)
                .weeklyAverage(4.0)
                .weekStartDate(java.time.LocalDate.now())
                .weekEndDate(java.time.LocalDate.now().plusDays(7))
                .calculatedAt(java.time.LocalDateTime.now())
                .build());

        // Verify pre-conditions
        assertEquals(1, moodEntryRepository.countByUser(testUser));
        assertEquals(1, copingSessionRepository.countByUser(testUser));
        assertTrue(streakRepository.findByUser(testUser).isPresent());
        assertEquals(1, stressPatternRepository.findByUserOrderByWeekStartDateDesc(testUser).size());

        // Execute deletion
        mockMvc.perform(delete("/api/user/clear-data"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message", is("All personal logs and activity data have been successfully cleared.")));

        // Verify post-conditions
        assertEquals(0, moodEntryRepository.countByUser(testUser));
        assertEquals(0, copingSessionRepository.countByUser(testUser));
        assertTrue(streakRepository.findByUser(testUser).isEmpty());
        assertEquals(0, stressPatternRepository.findByUserOrderByWeekStartDateDesc(testUser).size());
    }

    @Test
    void clearUserData_Unauthenticated() throws Exception {
        mockMvc.perform(delete("/api/user/clear-data"))
                .andExpect(status().isForbidden());
    }
}
