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
public class JournalPromptResponse {

    private String promptTitle;
    private String promptQuestion;
    private List<String> followUpQuestions;
    private int estimatedMinutes;
    private String tone;

    @Builder.Default
    private boolean aiAvailable = true;
}
