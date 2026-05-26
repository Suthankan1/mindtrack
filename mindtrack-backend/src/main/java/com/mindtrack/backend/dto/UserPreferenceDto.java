package com.mindtrack.backend.dto;

import jakarta.validation.constraints.Pattern;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserPreferenceDto {
    @Pattern(regexp = "^(dark|light|system)$", message = "Theme mode must be dark, light, or system")
    private String themeMode;

    private Boolean reminderEnabled;

    @Pattern(regexp = "^(0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]$", message = "Reminder time must be in HH:mm format")
    private String reminderTime;

    @Pattern(regexp = "^(Breathing|Grounding|Journaling|Walk)$", message = "Default coping technique must be Breathing, Grounding, Journaling, or Walk")
    private String defaultCopingTechnique;

    @Pattern(regexp = "^(standard|strict)$", message = "Privacy mode must be standard or strict")
    private String privacyMode;

    private Boolean aiJournalAnalysisEnabled;
    private Boolean aiChatHistoryEnabled;
    private Boolean shareNotesWithAi;
}
