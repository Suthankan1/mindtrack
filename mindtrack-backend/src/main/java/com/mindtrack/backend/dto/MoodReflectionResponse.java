package com.mindtrack.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MoodReflectionResponse {
    private String oneSentenceReflection;
    private String suggestedNextStep;
    private String recommendedTechnique;
    private boolean showCrisisResources;
    private boolean aiAvailable;
}
