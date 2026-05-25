package com.mindtrack.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CopingSuggestResponse {
    private String technique;
    private String reason;
    private int durationMinutes;
    private String encouragement;
}
