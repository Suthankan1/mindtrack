package com.mindtrack.backend.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.mindtrack.backend.dto.ChatResponse;
import com.mindtrack.backend.dto.CopingSuggestResponse;
import com.mindtrack.backend.dto.SentimentAnalysisResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class JsonExtractionServiceTest {

    private JsonExtractionService jsonExtractionService;
    private ObjectMapper objectMapper;

    @BeforeEach
    void setUp() {
        objectMapper = new ObjectMapper();
        jsonExtractionService = new JsonExtractionService(objectMapper);
    }

    @Test
    void cleanAndExtractJson_stripsMarkdownFences() {
        String inputJson = "```json\n{\n  \"key\": \"value\"\n}\n```";
        String cleaned = jsonExtractionService.cleanAndExtractJson(inputJson);
        assertEquals("{\n  \"key\": \"value\"\n}", cleaned);
    }

    @Test
    void cleanAndExtractJson_stripsNormalFences() {
        String inputJson = "```\n{\n  \"key\": \"value\"\n}\n```";
        String cleaned = jsonExtractionService.cleanAndExtractJson(inputJson);
        assertEquals("{\n  \"key\": \"value\"\n}", cleaned);
    }

    @Test
    void cleanAndExtractJson_extractsJsonFromNoisyText() {
        String inputNoisy = "Sure! Here is the response you requested: {\"key\": \"value\"} Let me know if you need anything else!";
        String cleaned = jsonExtractionService.cleanAndExtractJson(inputNoisy);
        assertEquals("{\"key\": \"value\"}", cleaned);
    }

    @Test
    void extractAndParse_sentimentAnalysisResponse_success() {
        String rawJson = "```json\n" +
                "{\n" +
                "  \"sentiment\": \"positive\",\n" +
                "  \"emotionalTone\": \"hopeful\",\n" +
                "  \"themes\": [\"growth\", \"reflection\"],\n" +
                "  \"confidence\": 0.95,\n" +
                "  \"supportMessage\": \"It is wonderful to see you reflecting on your progress!\"\n" +
                "}\n" +
                "```";

        SentimentAnalysisResponse parsed = jsonExtractionService.extractAndParse(rawJson, SentimentAnalysisResponse.class);
        assertNotNull(parsed);
        assertEquals("positive", parsed.getSentiment());
        assertEquals("hopeful", parsed.getEmotionalTone());
        assertEquals(2, parsed.getThemes().size());
        assertTrue(parsed.getThemes().contains("reflection"));
        assertEquals(0.95, parsed.getConfidence());
        assertEquals("It is wonderful to see you reflecting on your progress!", parsed.getSupportMessage());
        assertTrue(parsed.isAiAvailable());
    }

    @Test
    void extractAndParse_copingSuggestResponse_success() {
        String rawJson = "Noisy lead-in text {\n" +
                "  \"technique\": \"breathing_box\",\n" +
                "  \"reason\": \"Box breathing helps regulate heart rate and bring calm attention.\",\n" +
                "  \"durationMinutes\": 4,\n" +
                "  \"encouragement\": \"Take four seconds to breathe, hold, and release.\"\n" +
                "} and noisy ending text";

        CopingSuggestResponse parsed = jsonExtractionService.extractAndParse(rawJson, CopingSuggestResponse.class);
        assertNotNull(parsed);
        assertEquals("breathing_box", parsed.getTechnique());
        assertEquals("Box breathing helps regulate heart rate and bring calm attention.", parsed.getReason());
        assertEquals(4, parsed.getDurationMinutes());
        assertEquals("Take four seconds to breathe, hold, and release.", parsed.getEncouragement());
        assertTrue(parsed.isAiAvailable());
    }

    @Test
    void extractAndParse_chatResponse_success() {
        String rawJson = "{\n" +
                "  \"reply\": \"I hear you. That sounds like a challenging situation.\",\n" +
                "  \"suggestedFollowUps\": [\"How can I support you?\", \"What would help most right now?\"]\n" +
                "}";

        ChatResponse parsed = jsonExtractionService.extractAndParse(rawJson, ChatResponse.class);
        assertNotNull(parsed);
        assertEquals("I hear you. That sounds like a challenging situation.", parsed.getReply());
        assertEquals(2, parsed.getSuggestedFollowUps().size());
        assertTrue(parsed.isAiAvailable());
    }

    @Test
    void extractAndParse_missingRequiredFields_throwsException() {
        String invalidJson = "{\n" +
                "  \"sentiment\": \"negative\"\n" + // Missing emotionalTone, supportMessage, themes
                "}";

        RuntimeException ex = assertThrows(RuntimeException.class, () ->
                jsonExtractionService.extractAndParse(invalidJson, SentimentAnalysisResponse.class)
        );
        assertTrue(ex.getMessage().contains("Missing required fields"));
    }

    @Test
    void extractAndParse_malformedJson_throwsException() {
        String malformed = "{\"sentiment\": \"positive\", }"; // Trailing comma

        assertThrows(RuntimeException.class, () ->
                jsonExtractionService.extractAndParse(malformed, SentimentAnalysisResponse.class)
        );
    }
}
