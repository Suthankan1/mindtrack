package com.mindtrack.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserPreferenceDto {
    private String themeMode;
    private boolean reminderEnabled;
    private String reminderTime;
    private String defaultCopingTechnique;
    private String privacyMode;
    private boolean aiJournalAnalysisEnabled;
    private boolean aiChatHistoryEnabled;
    private boolean shareNotesWithAi;
}
