package com.mindtrack.backend.controller;

import com.mindtrack.backend.dto.ChangePasswordRequest;
import com.mindtrack.backend.dto.UserStatsResponse;
import com.mindtrack.backend.dto.UserPreferenceDto;
import com.mindtrack.backend.model.Streak;
import com.mindtrack.backend.model.User;
import com.mindtrack.backend.model.UserPreference;
import com.mindtrack.backend.repository.MoodEntryRepository;
import com.mindtrack.backend.repository.UserRepository;
import com.mindtrack.backend.repository.UserPreferenceRepository;
import com.mindtrack.backend.service.StreakService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneOffset;
import java.time.temporal.ChronoUnit;
import java.util.Map;

/**
 * REST controller for user-level management and statistics in MindTrack.
 *
 * <p>Aggregates mood data, streaks, and account tenure into a single stats
 * response used by both the mobile profile screen and the web dashboard.
 * Also handles user account modifications like changing passwords.
 */
@RestController
@RequestMapping("/api/user")
public class UserController {

    private final UserRepository userRepository;
    private final MoodEntryRepository moodEntryRepository;
    private final StreakService streakService;
    private final PasswordEncoder passwordEncoder;
    private final UserPreferenceRepository userPreferenceRepository;

    /**
     * Constructs the {@code UserController} with all required dependencies.
     *
     * @param userRepository            repository for user account lookups
     * @param moodEntryRepository       repository for mood entry aggregation queries
     * @param streakService             service to retrieve current and longest check-in streaks
     * @param passwordEncoder           encoder for BCrypt password verification
     * @param userPreferenceRepository  repository for user preferences persistence
     */
    public UserController(
            UserRepository userRepository,
            MoodEntryRepository moodEntryRepository,
            StreakService streakService,
            PasswordEncoder passwordEncoder,
            UserPreferenceRepository userPreferenceRepository) {
        this.userRepository = userRepository;
        this.moodEntryRepository = moodEntryRepository;
        this.streakService = streakService;
        this.passwordEncoder = passwordEncoder;
        this.userPreferenceRepository = userPreferenceRepository;
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

    /**
     * Changes the password of the currently authenticated user after verifying
     * credentials and validating standard password complexity.
     *
     * @param authentication the Spring Security authentication context (populated by JWT filter)
     * @param request        the password change payload containing current and new passwords
     * @return {@code 200 OK} with a safe success response on success,
     *         or {@code 400 Bad Request} if verification fails or the new password is too short
     */
    @PostMapping("/change-password")
    public ResponseEntity<?> changePassword(
            Authentication authentication,
            @Valid @RequestBody ChangePasswordRequest request) {
        String email = authentication.getName();
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));

        if (!passwordEncoder.matches(request.getCurrentPassword(), user.getPasswordHash())) {
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(Map.of("message", "Current password is incorrect."));
        }

        if (request.getNewPassword().equals(request.getCurrentPassword())) {
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(Map.of("message", "New password cannot be the same as the current password."));
        }

        user.setPasswordHash(passwordEncoder.encode(request.getNewPassword()));
        userRepository.save(user);

        return ResponseEntity.ok(Map.of("message", "Password updated successfully."));
    }

    /**
     * Retrieves the preferences of the currently authenticated user.
     * If preferences do not exist yet, they are initialized with default values.
     *
     * @param authentication the Spring Security authentication context
     * @return 200 OK with the UserPreferenceDto
     */
    @GetMapping("/preferences")
    public ResponseEntity<UserPreferenceDto> getPreferences(Authentication authentication) {
        String email = authentication.getName();
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));

        UserPreference preference = userPreferenceRepository.findByUser(user)
                .orElseGet(() -> {
                    UserPreference defaultPreference = UserPreference.builder()
                            .user(user)
                            .themeMode("dark")
                            .reminderEnabled(true)
                            .reminderTime("20:00")
                            .defaultCopingTechnique("Breathing")
                            .privacyMode("standard")
                            .build();
                    return userPreferenceRepository.save(defaultPreference);
                });

        return ResponseEntity.ok(convertToDto(preference));
    }

    /**
     * Updates the preferences of the currently authenticated user.
     *
     * @param authentication the Spring Security authentication context
     * @param dto the new preferences values
     * @return 200 OK with the updated UserPreferenceDto
     */
    @PutMapping("/preferences")
    public ResponseEntity<UserPreferenceDto> updatePreferences(
            Authentication authentication,
            @Valid @RequestBody UserPreferenceDto dto) {
        String email = authentication.getName();
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));

        UserPreference preference = userPreferenceRepository.findByUser(user)
                .orElseGet(() -> UserPreference.builder().user(user).build());

        preference.setThemeMode(dto.getThemeMode());
        preference.setReminderEnabled(dto.isReminderEnabled());
        preference.setReminderTime(dto.getReminderTime());
        preference.setDefaultCopingTechnique(dto.getDefaultCopingTechnique());
        preference.setPrivacyMode(dto.getPrivacyMode());

        UserPreference saved = userPreferenceRepository.save(preference);
        return ResponseEntity.ok(convertToDto(saved));
    }

    private UserPreferenceDto convertToDto(UserPreference preference) {
        return UserPreferenceDto.builder()
                .themeMode(preference.getThemeMode())
                .reminderEnabled(preference.isReminderEnabled())
                .reminderTime(preference.getReminderTime())
                .defaultCopingTechnique(preference.getDefaultCopingTechnique())
                .privacyMode(preference.getPrivacyMode())
                .build();
    }
}
