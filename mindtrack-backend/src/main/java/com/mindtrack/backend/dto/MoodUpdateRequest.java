package com.mindtrack.backend.dto;

import jakarta.validation.constraints.Size;
import jakarta.validation.constraints.AssertTrue;
import lombok.Data;

import java.util.List;
import java.util.Set;

@Data
public class MoodUpdateRequest {

    private static final Set<String> VALID_TAGS = Set.of("Sleep", "Work", "Exercise", "Social", "Mindfulness", "Nutrition", "Other");

    private String note;

    @Size(max = 5, message = "Maximum 5 tags per entry")
    private List<String> tags;

    @AssertTrue(message = "Tags must be one of: Sleep, Work, Exercise, Social, Mindfulness, Nutrition, Other")
    public boolean isTagsValid() {
        return tags == null || tags.stream().allMatch(VALID_TAGS::contains);
    }
}
