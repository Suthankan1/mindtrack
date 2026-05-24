package com.mindtrack.backend.service;

import com.mindtrack.backend.model.Streak;
import com.mindtrack.backend.model.User;
import com.mindtrack.backend.repository.StreakRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;

/**
 * Service responsible for maintaining daily mood check-in streaks for MindTrack users.
 *
 * <p>A streak increments when a user logs at least one mood entry on consecutive days.
 * Logging multiple times in the same day does not increment the streak beyond 1 for that day.
 * Missing a day resets the current streak to 1 on the next check-in.
 */
@Service
public class StreakService {

    private final StreakRepository streakRepository;

    /**
     * Constructs the {@code StreakService} with its required repository.
     *
     * @param streakRepository JPA repository for streak persistence
     */
    public StreakService(StreakRepository streakRepository) {
        this.streakRepository = streakRepository;
    }

    /**
     * Updates the check-in streak for the given user based on today's date.
     *
     * <p>Streak rules:
     * <ul>
     *   <li>First-ever check-in: streak starts at 1</li>
     *   <li>Check-in on the same day as last: streak unchanged</li>
     *   <li>Check-in on the day immediately after last: streak increments by 1</li>
     *   <li>Gap of more than one day: streak resets to 1</li>
     * </ul>
     * The longest streak is updated whenever the current streak exceeds the previous record.
     *
     * @param user the authenticated user whose streak should be updated
     * @return the persisted {@link Streak} entity with updated values
     */
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

    /**
     * Retrieves the current streak record for a user, returning a zero-valued
     * default if no streak record exists yet.
     *
     * @param user the user whose streak should be fetched
     * @return the {@link Streak} entity, or a transient default instance if not yet persisted
     */
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
