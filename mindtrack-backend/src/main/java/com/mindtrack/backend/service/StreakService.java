package com.mindtrack.backend.service;

import com.mindtrack.backend.model.Streak;
import com.mindtrack.backend.model.User;
import com.mindtrack.backend.repository.StreakRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;

@Service
public class StreakService {

    private final StreakRepository streakRepository;

    public StreakService(StreakRepository streakRepository) {
        this.streakRepository = streakRepository;
    }

    @Transactional
    public Streak updateStreak(User user) {
        LocalDate today = LocalDate.now();
        Streak streak = streakRepository.findByUser(user)
                .orElseGet(() -> Streak.builder()
                        .user(user)
                        .currentStreak(0)
                        .longestStreak(0)
                        .lastCheckInDate(null)
                        .build());

        LocalDate lastDate = streak.getLastCheckInDate();

        if (lastDate == null) {
            streak.setCurrentStreak(1);
            streak.setLongestStreak(Math.max(streak.getLongestStreak(), 1));
            streak.setLastCheckInDate(today);
        } else if (lastDate.equals(today)) {
            // Already logged today, streak remains unchanged
        } else if (lastDate.equals(today.minusDays(1))) {
            // Logged yesterday, increment streak
            int newStreak = streak.getCurrentStreak() + 1;
            streak.setCurrentStreak(newStreak);
            if (newStreak > streak.getLongestStreak()) {
                streak.setLongestStreak(newStreak);
            }
            streak.setLastCheckInDate(today);
        } else {
            // Streak broken, reset to 1
            streak.setCurrentStreak(1);
            streak.setLastCheckInDate(today);
        }

        return streakRepository.save(streak);
    }

    @Transactional(readOnly = true)
    public Streak getStreak(User user) {
        return streakRepository.findByUser(user)
                .orElseGet(() -> Streak.builder()
                        .user(user)
                        .currentStreak(0)
                        .longestStreak(0)
                        .lastCheckInDate(null)
                        .build());
    }
}
