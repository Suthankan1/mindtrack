package com.mindtrack.backend.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.mindtrack.backend.dto.ChatMessageDto;
import com.mindtrack.backend.dto.ChatRequest;
import com.mindtrack.backend.dto.CopingSuggestRequest;
import com.mindtrack.backend.dto.MoodContextDto;
import com.mindtrack.backend.dto.MoodAnomalyResponse;
import com.mindtrack.backend.model.User;
import com.mindtrack.backend.repository.UserRepository;
import com.mindtrack.backend.service.AiInsightService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

import static org.hamcrest.Matchers.is;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
public class AiInsightControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private UserRepository userRepository;

    @MockBean
    private AiInsightService aiInsightService;

    private User testUser;

    @BeforeEach
    void setUp() {
        testUser = User.builder()
                .email("testuser@example.com")
                .passwordHash("password")
                .anonymousMode(false)
                .build();

        org.mockito.Mockito.when(userRepository.findByEmail("testuser@example.com"))
                .thenReturn(Optional.of(testUser));
    }

    @Test
    @WithMockUser(username = "testuser@example.com")
    void chat_MessageBlank_ReturnsBadRequest() throws Exception {
        ChatRequest request = ChatRequest.builder()
                .message(" ") // Blank message
                .conversationHistory(new ArrayList<>())
                .moodContext(new MoodContextDto(3, 3.5))
                .build();

        mockMvc.perform(post("/api/ai/chat")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error", is("Validation Failed")))
                .andExpect(jsonPath("$.errors.message", is("Message cannot be blank")));
    }

    @Test
    @WithMockUser(username = "testuser@example.com")
    void chat_HistoryTooLong_ReturnsBadRequest() throws Exception {
        List<ChatMessageDto> history = new ArrayList<>();
        for (int i = 0; i < 11; i++) {
            history.add(new ChatMessageDto("user", "Hello " + i));
        }

        ChatRequest request = ChatRequest.builder()
                .message("Valid message")
                .conversationHistory(history) // 11 messages (max 10 allowed)
                .moodContext(new MoodContextDto(3, 3.5))
                .build();

        mockMvc.perform(post("/api/ai/chat")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error", is("Validation Failed")))
                .andExpect(jsonPath("$.errors.conversationHistory", is("Conversation history cannot exceed 10 messages")));
    }

    @Test
    @WithMockUser(username = "testuser@example.com")
    void copingSuggest_MoodScoreInvalid_ReturnsBadRequest() throws Exception {
        CopingSuggestRequest request = CopingSuggestRequest.builder()
                .moodScore(6) // Valid range is 1-5
                .timeOfDay("Evening")
                .recentAverage(3.5)
                .lastTags(List.of("tag1"))
                .build();

        mockMvc.perform(post("/api/ai/coping/suggest")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error", is("Validation Failed")))
                .andExpect(jsonPath("$.errors.moodScore", is("Mood score must be between 1 and 5")));
    }

    @Test
    @WithMockUser(username = "testuser@example.com")
    void copingSuggest_RecentAverageInvalid_ReturnsBadRequest() throws Exception {
        CopingSuggestRequest request = CopingSuggestRequest.builder()
                .moodScore(3)
                .timeOfDay("Morning")
                .recentAverage(5.5) // Valid range is 1.0 - 5.0
                .lastTags(List.of("tag1"))
                .build();

        mockMvc.perform(post("/api/ai/coping/suggest")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error", is("Validation Failed")))
                .andExpect(jsonPath("$.errors.recentAverage", is("Recent average must be between 1.0 and 5.0")));
    }

    @Test
    @WithMockUser(username = "testuser@example.com")
    void copingSuggest_TagsTooMany_ReturnsBadRequest() throws Exception {
        List<String> tags = List.of("tag1", "tag2", "tag3", "tag4", "tag5", "tag6"); // max 5 allowed

        CopingSuggestRequest request = CopingSuggestRequest.builder()
                .moodScore(3)
                .timeOfDay("Afternoon")
                .recentAverage(3.0)
                .lastTags(tags)
                .build();

        mockMvc.perform(post("/api/ai/coping/suggest")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error", is("Validation Failed")))
                .andExpect(jsonPath("$.errors.lastTags", is("Last tags cannot exceed 5 items")));
    }

    @Test
    @WithMockUser(username = "testuser@example.com")
    void getMoodAnomaly_ReturnsResponse() throws Exception {
        MoodAnomalyResponse response = MoodAnomalyResponse.builder()
                .riskLevel("MEDIUM")
                .detectedPatterns(List.of("Sudden mood drop from personal baseline"))
                .suggestedAction("Take a slow box breath.")
                .supportiveInsight("We notice some drops from baseline.")
                .confidence(0.8)
                .insufficientData(false)
                .build();

        org.mockito.Mockito.when(aiInsightService.getMoodAnomaly(org.mockito.ArgumentMatchers.any(User.class)))
                .thenReturn(response);

        mockMvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get("/api/ai/anomaly/weekly"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.riskLevel", is("MEDIUM")))
                .andExpect(jsonPath("$.detectedPatterns[0]", is("Sudden mood drop from personal baseline")))
                .andExpect(jsonPath("$.insufficientData", is(false)));
    }
}
