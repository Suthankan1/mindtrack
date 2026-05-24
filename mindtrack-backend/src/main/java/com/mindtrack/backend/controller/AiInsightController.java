package com.mindtrack.backend.controller;

import com.mindtrack.backend.model.StressPattern;
import com.mindtrack.backend.model.User;
import com.mindtrack.backend.repository.UserRepository;
import com.mindtrack.backend.repository.MoodEntryRepository;
import com.mindtrack.backend.service.MoodPatternService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

/**
 * REST controller for AI-generated mental health insights.
 */
@RestController
@RequestMapping("/api/ai")
public class AiInsightController {

    private final UserRepository userRepository;
    private final MoodPatternService moodPatternService;
    private final MoodEntryRepository moodEntryRepository;

    public AiInsightController(
            UserRepository userRepository,
            MoodPatternService moodPatternService,
            MoodEntryRepository moodEntryRepository) {
        this.userRepository = userRepository;
        this.moodPatternService = moodPatternService;
        this.moodEntryRepository = moodEntryRepository;
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
}
