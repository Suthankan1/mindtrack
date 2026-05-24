package com.mindtrack.backend.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.mindtrack.backend.dto.CopingSessionRequest;
import com.mindtrack.backend.model.CopingSession;
import com.mindtrack.backend.model.User;
import com.mindtrack.backend.repository.CopingSessionRepository;
import com.mindtrack.backend.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDateTime;
import java.util.List;

import static org.hamcrest.Matchers.*;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
public class CopingSessionControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private CopingSessionRepository copingSessionRepository;

    @Autowired
    private ObjectMapper objectMapper;

    private User testUser;

    @BeforeEach
    void setUp() {
        copingSessionRepository.deleteAll();
        userRepository.deleteAll();

        testUser = User.builder()
                .email("testuser@example.com")
                .passwordHash("passwordHash")
                .anonymousMode(false)
                .build();
        testUser = userRepository.save(testUser);
    }

    @Test
    @WithMockUser(username = "testuser@example.com")
    void logSession_Success() throws Exception {
        CopingSessionRequest request = CopingSessionRequest.builder()
                .type("breathing")
                .durationSeconds(240)
                .build();

        mockMvc.perform(post("/api/coping/session")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id", notNullValue()))
                .andExpect(jsonPath("$.userId", is(testUser.getId().toString())))
                .andExpect(jsonPath("$.type", is("breathing")))
                .andExpect(jsonPath("$.durationSeconds", is(240)))
                .andExpect(jsonPath("$.completedAt", notNullValue()));

        List<CopingSession> sessions = copingSessionRepository.findByUserOrderByCompletedAtDesc(testUser);
        assertEquals(1, sessions.size());
        assertEquals("breathing", sessions.get(0).getType());
        assertEquals(240, sessions.get(0).getDurationSeconds());
    }

    @Test
    @WithMockUser(username = "testuser@example.com")
    void logSession_ValidationError() throws Exception {
        CopingSessionRequest request = CopingSessionRequest.builder()
                .type("") // Blank type is invalid
                .durationSeconds(0) // Duration must be >= 1
                .build();

        mockMvc.perform(post("/api/coping/session")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error", is("Validation Failed")));
    }

    @Test
    @WithMockUser(username = "testuser@example.com")
    void getHistory_Success() throws Exception {
        // Log 12 sessions (more than the limit of 10)
        for (int i = 1; i <= 12; i++) {
            CopingSession session = CopingSession.builder()
                    .user(testUser)
                    .type(i % 2 == 0 ? "breathing" : "grounding")
                    .durationSeconds(60 * i)
                    .completedAt(LocalDateTime.now().minusMinutes(15 - i))
                    .build();
            copingSessionRepository.save(session);
        }

        mockMvc.perform(get("/api/coping/history"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$", hasSize(10)))
                // Verify ordering (most recent first)
                .andExpect(jsonPath("$[0].durationSeconds", is(12 * 60)));
    }

    @Test
    @WithMockUser(username = "testuser@example.com")
    void getStats_Success() throws Exception {
        // Save sessions: 2 breathing (120s, 180s) and 1 grounding (60s)
        copingSessionRepository.save(CopingSession.builder()
                .user(testUser)
                .type("breathing")
                .durationSeconds(120)
                .completedAt(LocalDateTime.now())
                .build());

        copingSessionRepository.save(CopingSession.builder()
                .user(testUser)
                .type("breathing")
                .durationSeconds(180)
                .completedAt(LocalDateTime.now())
                .build());

        copingSessionRepository.save(CopingSession.builder()
                .user(testUser)
                .type("grounding")
                .durationSeconds(60)
                .completedAt(LocalDateTime.now())
                .build());

        // Total seconds: 120 + 180 + 60 = 360s = 6 minutes. Total sessions = 3. Most used = breathing.
        mockMvc.perform(get("/api/coping/stats"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.totalSessions", is(3)))
                .andExpect(jsonPath("$.totalMinutes", is(6)))
                .andExpect(jsonPath("$.mostUsedType", is("breathing")));
    }
}
