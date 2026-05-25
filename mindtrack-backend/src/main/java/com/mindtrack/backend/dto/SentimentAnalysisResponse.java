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
public class SentimentAnalysisResponse {
    private String sentiment;
    private String emotionalTone;
    private List<String> themes;
    private double confidence;
    private String supportMessage;
}
