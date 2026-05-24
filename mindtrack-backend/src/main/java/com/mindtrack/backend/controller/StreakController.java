package com.mindtrack.backend.controller;

import com.mindtrack.backend.dto.StreakResponse;
import com.mindtrack.backend.model.Streak;
import com.mindtrack.backend.model.User;
import com.mindtrack.backend.repository.UserRepository;
import com.mindtrack.backend.service.StreakService;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

/**
 * REST controller for retrieving individual user check-in streaks.
 */
@RestController
@RequestMapping("/api/streak")
public class StreakController {

    private final UserRepository userRepository;
    private final StreakService streakService;

    /**
     * Constructs the {@code StreakController} with required repositories and services.
     *
     * @param userRepository repository to look up authenticated users
     * @param streakService  service to fetch check-in streak stats
     */
    public StreakController(UserRepository userRepository, StreakService streakService) {
        this.userRepository = userRepository;
        this.streakService = streakService;
    }

    /**
     * GET /api/streak
     *
     * <p>Exposes current and historical longest daily mood check-in streaks
     * for the currently authenticated user.
     *
     * @param authentication the authenticated user details from the JWT security context
     * @return {@code 200 OK} with streak details, or {@code 401 Unauthorized} if user is missing
     */
    @GetMapping
    public ResponseEntity<StreakResponse> getStreak(Authentication authentication) {
        String email = authentication.getName();
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));

        Streak streak = streakService.getStreak(user);

        StreakResponse response = StreakResponse.builder()
                .currentStreak(streak.getCurrentStreak())
                .longestStreak(streak.getLongestStreak())
                .lastCheckInDate(streak.getLastCheckInDate())
                .build();

        return ResponseEntity.ok(response);
    }
}
