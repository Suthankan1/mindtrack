package com.mindtrack.backend.controller;

import com.mindtrack.backend.dto.CopingSessionRequest;
import com.mindtrack.backend.dto.CopingSessionResponse;
import com.mindtrack.backend.dto.CopingStatsResponse;
import com.mindtrack.backend.model.CopingSession;
import com.mindtrack.backend.model.User;
import com.mindtrack.backend.repository.CopingSessionRepository;
import com.mindtrack.backend.repository.UserRepository;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * REST controller for coping session logging and stats.
 */
@RestController
@RequestMapping("/api/coping")
public class CopingSessionController {

    private final UserRepository userRepository;
    private final CopingSessionRepository copingSessionRepository;

    public CopingSessionController(UserRepository userRepository, CopingSessionRepository copingSessionRepository) {
        this.userRepository = userRepository;
        this.copingSessionRepository = copingSessionRepository;
    }

    /**
     * POST /api/coping/session
     * Logs a new coping session for the authenticated user.
     */
    @PostMapping("/session")
    public ResponseEntity<CopingSessionResponse> logSession(
            @Valid @RequestBody CopingSessionRequest request,
            Authentication authentication) {

        String email = authentication.getName();
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));

        CopingSession copingSession = CopingSession.builder()
                .user(user)
                .type(request.getType())
                .durationSeconds(request.getDurationSeconds())
                .completedAt(LocalDateTime.now())
                .build();

        CopingSession savedSession = copingSessionRepository.save(copingSession);

        return ResponseEntity.status(HttpStatus.CREATED)
                .body(CopingSessionResponse.fromEntity(savedSession));
    }

    /**
     * GET /api/coping/history
     * Returns the last 10 coping sessions for the authenticated user.
     */
    @GetMapping("/history")
    public ResponseEntity<List<CopingSessionResponse>> getHistory(Authentication authentication) {
        String email = authentication.getName();
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));

        List<CopingSession> sessions = copingSessionRepository.findByUserOrderByCompletedAtDesc(user);
        List<CopingSessionResponse> responses = sessions.stream()
                .limit(10)
                .map(CopingSessionResponse::fromEntity)
                .collect(Collectors.toList());

        return ResponseEntity.ok(responses);
    }

    /**
     * GET /api/coping/stats
     * Returns totalSessions, totalMinutes, and mostUsedType for the authenticated user.
     */
    @GetMapping("/stats")
    public ResponseEntity<CopingStatsResponse> getStats(Authentication authentication) {
        String email = authentication.getName();
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found"));

        List<CopingSession> sessions = copingSessionRepository.findByUserOrderByCompletedAtDesc(user);

        long totalSessions = sessions.size();
        long totalSeconds = sessions.stream()
                .mapToLong(CopingSession::getDurationSeconds)
                .sum();
        long totalMinutes = totalSeconds / 60;

        String mostUsedType = sessions.stream()
                .collect(Collectors.groupingBy(CopingSession::getType, Collectors.counting()))
                .entrySet().stream()
                .max(Map.Entry.comparingByValue())
                .map(Map.Entry::getKey)
                .orElse("N/A");

        CopingStatsResponse stats = CopingStatsResponse.builder()
                .totalSessions(totalSessions)
                .totalMinutes(totalMinutes)
                .mostUsedType(mostUsedType)
                .build();

        return ResponseEntity.ok(stats);
    }
}
