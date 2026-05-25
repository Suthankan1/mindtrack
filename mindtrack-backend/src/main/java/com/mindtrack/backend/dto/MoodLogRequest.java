package com.mindtrack.backend.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import jakarta.validation.constraints.AssertTrue;
import lombok.Data;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Set;

@Data
public class MoodLogRequest {

    private static final Set<String> VALID_TAGS = Set.of("Sleep", "Work", "Exercise", "Social", "Mindfulness", "Nutrition", "Other");

    @NotNull(message = "Mood score is required")
    @Min(value = 1, message = "Mood score must be between 1 and 5")
    @Max(value = 5, message = "Mood score must be between 1 and 5")
    private Integer moodScore;

    private String note;

    private LocalDateTime timestamp;

    @Size(max = 5, message = "Maximum 5 tags per entry")
    private List<String> tags;

    @AssertTrue(message = "Tags must be one of: Sleep, Work, Exercise, Social, Mindfulness, Nutrition, Other")
    public boolean isTagsValid() {
        return tags == null || tags.stream().allMatch(VALID_TAGS::contains);
    }
}
