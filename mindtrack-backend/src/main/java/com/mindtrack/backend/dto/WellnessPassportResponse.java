package com.mindtrack.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class WellnessPassportResponse {
    private double averageMood;
    private int streak;
    private List<String> topTags;
    private int copingSessionsCompleted;
    private String aiWeeklyInsight;
    private MoodAnomalyResponse anomalyRadarResult;
}
