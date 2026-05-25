package com.mindtrack.backend.dto;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
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
public class CopingSuggestRequest {

    @Min(value = 1, message = "Mood score must be between 1 and 5")
    @Max(value = 5, message = "Mood score must be between 1 and 5")
    private int moodScore;

    private String timeOfDay;

    @DecimalMin(value = "1.0", message = "Recent average must be between 1.0 and 5.0")
    @DecimalMax(value = "5.0", message = "Recent average must be between 1.0 and 5.0")
    private double recentAverage;

    @Size(max = 5, message = "Last tags cannot exceed 5 items")
    private List<String> lastTags;
}
