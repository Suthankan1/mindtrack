package com.mindtrack.backend.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MoodReflectionRequest {

    @Min(value = 1, message = "Mood score must be between 1 and 5")
    @Max(value = 5, message = "Mood score must be between 1 and 5")
    private int moodScore;

    @Size(max = 10, message = "Tags cannot exceed 10 items")
    private List<String> tags;

    private String note;

    private Double recentAverage;
}
