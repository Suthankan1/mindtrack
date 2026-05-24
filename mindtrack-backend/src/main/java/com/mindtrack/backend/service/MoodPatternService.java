package com.mindtrack.backend.service;

import com.mindtrack.backend.model.MoodEntry;
import com.mindtrack.backend.model.StressPattern;
import com.mindtrack.backend.model.User;
import com.mindtrack.backend.repository.MoodEntryRepository;
import com.mindtrack.backend.repository.StressPatternRepository;
import com.mindtrack.backend.repository.UserRepository;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class MoodPatternService {

    private final MoodEntryRepository moodEntryRepository;
    private final StressPatternRepository stressPatternRepository;
    private final UserRepository userRepository;

    public MoodPatternService(
            MoodEntryRepository moodEntryRepository,
            StressPatternRepository stressPatternRepository,
            UserRepository userRepository) {
        this.moodEntryRepository = moodEntryRepository;
        this.stressPatternRepository = stressPatternRepository;
        this.userRepository = userRepository;
    }

    /**
     * Public method to calculate weekly stress pattern for a specific user and timeframe.
     */
    @Transactional
    public StressPattern calculateWeeklyPattern(User user, LocalDateTime start, LocalDateTime end) {
        List<MoodEntry> entries = moodEntryRepository.findByUserAndTimestampBetweenOrderByTimestampDesc(user, start, end);

        if (entries.isEmpty()) {
            return null;
        }

        double average = entries.stream()
                .mapToInt(MoodEntry::getMoodScore)
                .average()
                .orElse(0.0);

        // Group entries by DayOfWeek and find the day with the lowest average mood (peak stress day)
        Map<DayOfWeek, List<MoodEntry>> groupedByDay = entries.stream()
                .collect(Collectors.groupingBy(e -> e.getTimestamp().getDayOfWeek()));

        DayOfWeek peakDay = null;
        double lowestAvg = Double.MAX_VALUE;

        for (Map.Entry<DayOfWeek, List<MoodEntry>> entry : groupedByDay.entrySet()) {
            double avg = entry.getValue().stream()
                    .mapToInt(MoodEntry::getMoodScore)
                    .average()
                    .orElse(0.0);
            if (avg < lowestAvg) {
                lowestAvg = avg;
                peakDay = entry.getKey();
            }
        }

        String aiInsight;
        if (average < 2.5) {
            aiInsight = "High stress week detected";
        } else if (average > 3.5) {
            aiInsight = "Great week! Keep it up";
        } else {
            aiInsight = "Stable mood pattern. Continue tracking to see trends.";
        }

        StressPattern pattern = StressPattern.builder()
                .user(user)
                .weeklyAverage(average)
                .peakStressDay(peakDay != null ? peakDay.name() : "N/A")
                .aiInsight(aiInsight)
                .weekStartDate(start.toLocalDate())
                .weekEndDate(end.toLocalDate())
                .calculatedAt(LocalDateTime.now())
                .build();

        return stressPatternRepository.save(pattern);
    }

    /**
     * Scheduled task to compute and save weekly results for all users every Sunday midnight.
     */
    @Scheduled(cron = "0 0 0 * * SUN")
    @Transactional
    public void runWeeklyAggregation() {
        LocalDateTime end = LocalDateTime.now();
        LocalDateTime start = end.minusDays(7);

        List<User> users = userRepository.findAll();
        for (User user : users) {
            try {
                calculateWeeklyPattern(user, start, end);
            } catch (Exception e) {
                // Log or handle user-specific processing errors gracefully to not crash entire scheduler loop
                System.err.println("Error calculating stress pattern for user " + user.getId() + ": " + e.getMessage());
            }
        }
    }
}
