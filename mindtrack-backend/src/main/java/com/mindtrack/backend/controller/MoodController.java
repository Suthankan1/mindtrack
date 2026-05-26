package com.mindtrack.backend.controller;

import com.mindtrack.backend.ai.GeminiService;
import com.mindtrack.backend.dto.MoodEntryResponse;
import com.mindtrack.backend.dto.MoodLogRequest;
import com.mindtrack.backend.model.MoodEntry;
import com.mindtrack.backend.model.User;
import com.mindtrack.backend.repository.MoodEntryRepository;
import com.mindtrack.backend.repository.UserRepository;
import com.mindtrack.backend.service.RateLimitingService;
import com.mindtrack.backend.service.StreakService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * REST controller for mood tracking operations in MindTrack.
 *
 * <p>Exposes the following authenticated endpoints:
 * <ul>
 *   <li>{@code POST /api/mood/log}     — log a new mood entry (rate-limited to 5/hour)</li>
 *   <li>{@code GET  /api/mood/today}   — retrieve today's mood entries for the current user</li>
 *   <li>{@code GET  /api/mood/history} — retrieve mood history for a configurable number of days</li>
 * </ul>
 */
@RestController
@RequestMapping("/api/mood")
public class MoodController {

    private final UserRepository userRepository;
    private final MoodEntryRepository moodEntryRepository;
    private final StreakService streakService;
    private final RateLimitingService rateLimitingService;
    private final GeminiService geminiService;

    /**
     * Constructs the {@code MoodController} with all required dependencies.
     *
     * @param userRepository      repository for user lookups
     * @param moodEntryRepository repository for mood entry persistence and queries
     * @param streakService       service to update the user's check-in streak
     * @param rateLimitingService Bucket4j-based rate limiter (max 5 logs/hour per user)
     * @param geminiService       service for AI insights and crisis response
     */
    public MoodController(
            UserRepository userRepository,
            MoodEntryRepository moodEntryRepository,
            StreakService streakService,
            RateLimitingService rateLimitingService,
            GeminiService geminiService) {
        this.userRepository = userRepository;
        this.moodEntryRepository = moodEntryRepository;
        this.streakService = streakService;
        this.rateLimitingService = rateLimitingService;
        this.geminiService = geminiService;
    }

    /**
     * Logs a new mood entry for the authenticated user.
     *
     * <p>Enforces a rate limit of 5 mood logs per hour. On success, the user's
     * check-in streak is updated automatically.
     *
     * @param request        the validated mood log payload (score, optional note and tags)
     * @param authentication the Spring Security authentication context (populated by JWT filter)
     * @return {@code 201 Created} with the saved {@link MoodEntryResponse},
     *         {@code 429 Too Many Requests} if the rate limit is exceeded,
     *         or {@code 401 Unauthorized} if the user cannot be resolved
     */
    @PostMapping("/log")
    public ResponseEntity<MoodEntryResponse> logMood(
            @Valid @RequestBody MoodLogRequest request,
            Authentication authentication) {

        String email = authentication.getName();
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));

        // Rate limiting: max 5 mood logs per hour per user
        if (!rateLimitingService.tryConsume(user.getId())) {
            throw new ResponseStatusException(
                    HttpStatus.TOO_MANY_REQUESTS,
                    "Rate limit exceeded: maximum 5 mood logs per hour.");
        }

        LocalDateTime entryTimestamp = request.getTimestamp() != null ? request.getTimestamp() : LocalDateTime.now();
        MoodEntry moodEntry = MoodEntry.builder()
                .user(user)
                .moodScore(request.getMoodScore())
                .note(request.getNote())
                .tags(request.getTags())
                .timestamp(entryTimestamp)
                .build();

        MoodEntry savedEntry = moodEntryRepository.save(moodEntry);

        // Update user streak on mood check-in
        streakService.updateStreak(user);

        MoodEntryResponse response = MoodEntryResponse.fromEntity(savedEntry);
        if (isCrisisRisk(user)) {
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
            response.setCrisisAlert(true);
            response.setCrisisMessage(rawResponse);
            
            boolean available = rawResponse != null &&
                    !rawResponse.startsWith("Unable to generate AI") &&
                    !rawResponse.startsWith("No insight generated");
            response.setAiAvailable(available);
        }

        return ResponseEntity.status(HttpStatus.CREATED).body(response);
    }

    /**
     * Returns all mood entries logged by the authenticated user today (midnight to now).
     *
     * @param authentication the Spring Security authentication context
     * @return {@code 200 OK} with a list of {@link MoodEntryResponse} objects,
     *         sorted by timestamp descending; empty list if no entries exist today
     */
    @GetMapping("/today")
    public ResponseEntity<List<MoodEntryResponse>> getTodayMoods(Authentication authentication) {
        String email = authentication.getName();
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));

        LocalDateTime startOfToday = LocalDate.now().atStartOfDay();
        LocalDateTime endOfToday = LocalDate.now().atTime(LocalTime.MAX);

        List<MoodEntry> todayEntries = moodEntryRepository
                .findByUserAndTimestampBetweenOrderByTimestampDesc(user, startOfToday, endOfToday);

        List<MoodEntryResponse> responses = todayEntries.stream()
                .map(MoodEntryResponse::fromEntity)
                .collect(Collectors.toList());

        return ResponseEntity.ok(responses);
    }

    /**
     * Returns mood history for the authenticated user going back a specified number of days.
     *
     * @param days           the number of days to look back (defaults to 30 if not provided)
     * @param authentication the Spring Security authentication context
     * @return {@code 200 OK} with a list of {@link MoodEntryResponse} objects,
     *         sorted by timestamp descending
     */
    @GetMapping("/history")
    public ResponseEntity<List<MoodEntryResponse>> getMoodHistory(
            @RequestParam(value = "days", defaultValue = "30") int days,
            Authentication authentication) {

        String email = authentication.getName();
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));

        LocalDateTime start = LocalDateTime.now().minusDays(days);

        List<MoodEntry> historyEntries = moodEntryRepository
                .findByUserAndTimestampAfterOrderByTimestampDesc(user, start);

        List<MoodEntryResponse> responses = historyEntries.stream()
                .map(MoodEntryResponse::fromEntity)
                .collect(Collectors.toList());

        return ResponseEntity.ok(responses);
    }

    private boolean isCrisisRisk(User user) {
        // Get last 3 days of entries
        LocalDateTime threeDaysAgo = LocalDateTime.now().minusDays(3);
        List<MoodEntry> recentEntries = moodEntryRepository.findByUserAndTimestampAfterOrderByTimestampDesc(user, threeDaysAgo);
        
        Map<LocalDate, List<MoodEntry>> entriesByDate = recentEntries.stream()
                .collect(Collectors.groupingBy(entry -> entry.getTimestamp().toLocalDate()));
        
        if (entriesByDate.size() < 3) {
            return false;
        }
        
        return entriesByDate.values().stream()
                .allMatch(entries -> entries.stream()
                        .mapToInt(MoodEntry::getMoodScore)
                        .max()
                        .orElse(0) <= 2);
    }
}
