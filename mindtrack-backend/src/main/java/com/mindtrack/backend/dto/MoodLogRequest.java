package com.mindtrack.backend.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import lombok.Data;

import java.util.List;

@Data
public class MoodLogRequest {

    @NotNull(message = "Mood score is required")
    @Min(value = 1, message = "Mood score must be between 1 and 5")
    @Max(value = 5, message = "Mood score must be between 1 and 5")
    private Integer moodScore;

    private String note;

    private List<String> tags;
}
