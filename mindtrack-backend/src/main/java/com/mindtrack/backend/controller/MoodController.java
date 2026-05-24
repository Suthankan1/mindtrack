package com.mindtrack.backend.controller;

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
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/mood")
public class MoodController {

    private final UserRepository userRepository;
    private final MoodEntryRepository moodEntryRepository;
    private final StreakService streakService;
    private final RateLimitingService rateLimitingService;

    public MoodController(
            UserRepository userRepository,
            MoodEntryRepository moodEntryRepository,
            StreakService streakService,
            RateLimitingService rateLimitingService) {
        this.userRepository = userRepository;
        this.moodEntryRepository = moodEntryRepository;
        this.streakService = streakService;
        this.rateLimitingService = rateLimitingService;
    }

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

        MoodEntry moodEntry = MoodEntry.builder()
                .user(user)
                .moodScore(request.getMoodScore())
                .note(request.getNote())
                .tags(request.getTags())
                .timestamp(LocalDateTime.now())
                .build();

        MoodEntry savedEntry = moodEntryRepository.save(moodEntry);

        // Update user streak on mood check-in
        streakService.updateStreak(user);

        return ResponseEntity.status(HttpStatus.CREATED).body(MoodEntryResponse.fromEntity(savedEntry));
    }

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
}
