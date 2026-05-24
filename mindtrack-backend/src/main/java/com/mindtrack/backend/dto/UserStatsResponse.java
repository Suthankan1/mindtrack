package com.mindtrack.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserStatsResponse {
    private long totalEntries;
    private int currentStreak;
    private int longestStreak;
    private double avgMoodScore;
    private double avgMoodScoreThisWeek;
    private long joinedDaysAgo;
}
