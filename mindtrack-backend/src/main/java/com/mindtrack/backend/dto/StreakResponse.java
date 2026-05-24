package com.mindtrack.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

/**
 * Lightweight DTO to expose streak analytics.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class StreakResponse {
    private int currentStreak;
    private int longestStreak;
    private LocalDate lastCheckInDate;
}
