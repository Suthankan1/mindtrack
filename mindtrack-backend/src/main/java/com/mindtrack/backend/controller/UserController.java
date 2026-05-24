package com.mindtrack.backend.controller;

import com.mindtrack.backend.dto.UserStatsResponse;
import com.mindtrack.backend.model.Streak;
import com.mindtrack.backend.model.User;
import com.mindtrack.backend.repository.MoodEntryRepository;
import com.mindtrack.backend.repository.UserRepository;
import com.mindtrack.backend.service.StreakService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;

/**
 * REST controller for user-level statistics in MindTrack.
 *
 * <p>Aggregates mood data, streaks, and account tenure into a single stats
 * response used by both the mobile profile screen and the web dashboard.
 */
@RestController
@RequestMapping("/api/user")
public class UserController {

    private final UserRepository userRepository;
    private final MoodEntryRepository moodEntryRepository;
    private final StreakService streakService;

    /**
     * Constructs the {@code UserController} with all required dependencies.
     *
     * @param userRepository      repository for user account lookups
     * @param moodEntryRepository repository for mood entry aggregation queries
     * @param streakService       service to retrieve current and longest check-in streaks
     */
    public UserController(
            UserRepository userRepository,
            MoodEntryRepository moodEntryRepository,
            StreakService streakService) {
        this.userRepository = userRepository;
        this.moodEntryRepository = moodEntryRepository;
        this.streakService = streakService;
    }

    /**
     * Returns aggregated statistics for the currently authenticated user.
     *
     * <p>Computes and returns:
     * <ul>
     *   <li>Total mood entries ever logged</li>
     *   <li>Current and longest daily check-in streaks</li>
     *   <li>All-time average mood score (rounded to 2 d.p.)</li>
     *   <li>Average mood score for the past 7 days</li>
     *   <li>Number of days since the user registered</li>
     * </ul>
     *
     * @param authentication the Spring Security authentication context (populated by JWT filter)
     * @return {@code 200 OK} with a {@link UserStatsResponse},
     *         or {@code 401 Unauthorized} if the user cannot be resolved
     */
    @GetMapping("/stats")
    public ResponseEntity<UserStatsResponse> getUserStats(Authentication authentication) {
        String email = authentication.getName();
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));

        // Total entries
        long totalEntries = moodEntryRepository.countByUser(user);

        // Streak data
        Streak streak = streakService.getStreak(user);
        int currentStreak = streak.getCurrentStreak();
        int longestStreak = streak.getLongestStreak();

        // Average mood score — all time (default to 0.0 if no entries)
        Double rawAvg = moodEntryRepository.findAvgMoodScoreByUser(user);
        double avgMoodScore = rawAvg != null ? Math.round(rawAvg * 100.0) / 100.0 : 0.0;

        // Average mood score — this week (last 7 days)
        LocalDateTime sevenDaysAgo = LocalDateTime.now(ZoneOffset.UTC).minusDays(7);
        Double rawWeeklyAvg = moodEntryRepository.findAvgMoodScoreByUserSince(user, sevenDaysAgo);
        double avgMoodScoreThisWeek = rawWeeklyAvg != null ? Math.round(rawWeeklyAvg * 100.0) / 100.0 : 0.0;

        // Days since the user joined
        Instant createdAt = user.getCreatedAt();
        long joinedDaysAgo = ChronoUnit.DAYS.between(createdAt, Instant.now());

        UserStatsResponse stats = UserStatsResponse.builder()
                .totalEntries(totalEntries)
                .currentStreak(currentStreak)
                .longestStreak(longestStreak)
                .avgMoodScore(avgMoodScore)
                .avgMoodScoreThisWeek(avgMoodScoreThisWeek)
                .joinedDaysAgo(joinedDaysAgo)
                .build();

        return ResponseEntity.ok(stats);
    }
}
