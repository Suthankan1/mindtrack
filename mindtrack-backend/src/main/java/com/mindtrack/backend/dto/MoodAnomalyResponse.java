package com.mindtrack.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MoodAnomalyResponse {
    private String riskLevel; // LOW | MEDIUM | HIGH
    private List<String> detectedPatterns;
    private String suggestedAction;
    private String supportiveInsight;
    private double confidence;
    private boolean insufficientData;
}
