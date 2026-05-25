package com.mindtrack.backend.service;

import com.mindtrack.backend.ai.GeminiService;
import com.mindtrack.backend.model.MoodEntry;
import com.mindtrack.backend.model.StressPattern;
import com.mindtrack.backend.model.User;
import com.mindtrack.backend.repository.MoodEntryRepository;
import com.mindtrack.backend.repository.StressPatternRepository;
import com.mindtrack.backend.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
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

    private static final Logger log = LoggerFactory.getLogger(MoodPatternService.class);

    private final MoodEntryRepository moodEntryRepository;
    private final StressPatternRepository stressPatternRepository;
    private final UserRepository userRepository;
    private final GeminiService geminiService;

    public MoodPatternService(
            MoodEntryRepository moodEntryRepository,
            StressPatternRepository stressPatternRepository,
            UserRepository userRepository,
            GeminiService geminiService) {
        this.moodEntryRepository = moodEntryRepository;
        this.stressPatternRepository = stressPatternRepository;
        this.userRepository = userRepository;
        this.geminiService = geminiService;
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

        // Build scoreBreakdown by counting how many entries had each score (1-5)
        Map<Integer, Long> counts = entries.stream()
                .collect(Collectors.groupingBy(MoodEntry::getMoodScore, Collectors.counting()));
        String scoreBreakdown = java.util.stream.IntStream.rangeClosed(1, 5)
                .mapToObj(score -> score + ": " + counts.getOrDefault(score, 0L))
                .collect(Collectors.joining(", "));

        // Build topTags by finding the 3 most frequent tags from all entries this week
        List<String> allTags = entries.stream()
                .filter(e -> e.getTags() != null)
                .flatMap(e -> e.getTags().stream())
                .collect(Collectors.toList());

        Map<String, Long> tagFrequencies = allTags.stream()
                .collect(Collectors.groupingBy(tag -> tag, Collectors.counting()));

        String topTags = tagFrequencies.entrySet().stream()
                .sorted(Map.Entry.<String, Long>comparingByValue().reversed())
                .limit(3)
                .map(Map.Entry::getKey)
                .collect(Collectors.joining(", "));

        if (topTags.isEmpty()) {
            topTags = "None";
        }

        int entryCount = entries.size();
        String peakDayStr = peakDay != null ? peakDay.name() : "N/A";

        String geminiPrompt = String.format("""
        You are a compassionate mental health companion inside the MindTrack app.
        Analyze this user's mood data from the past week and give a warm, personalized insight.

        Mood entries this week: %d entries
        Average mood score: %.1f / 5.0
        Peak stress day (lowest average): %s
        Mood score breakdown: %s
        Most used tags: %s

        Write a 2-3 sentence insight that:
        1. Acknowledges their specific week pattern
        2. Highlights one positive or actionable observation
        3. Gives one gentle, practical suggestion

        Tone: warm, non-clinical, encouraging. Like a knowledgeable friend, not a doctor.
        Maximum 60 words. Do NOT use bullet points.
        """, entryCount, average, peakDayStr, scoreBreakdown, topTags);

        String aiInsight = geminiService.generateInsight(geminiPrompt, null, 0.7);

        StressPattern pattern = StressPattern.builder()
                .user(user)
                .weeklyAverage(average)
                .peakStressDay(peakDayStr)
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
                log.error("Error calculating stress pattern for user {}: {}", user.getId(), e.getMessage());
            }
        }
    }
}
