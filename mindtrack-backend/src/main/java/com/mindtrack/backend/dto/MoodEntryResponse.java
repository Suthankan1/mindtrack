package com.mindtrack.backend.dto;

import com.mindtrack.backend.model.MoodEntry;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MoodEntryResponse {
    private UUID id;
    private UUID userId;
    private int moodScore;
    private String note;
    private LocalDateTime timestamp;
    private List<String> tags;
    private boolean crisisAlert;
    private String crisisMessage;

    @Builder.Default
    private boolean aiAvailable = true;

    public static MoodEntryResponse fromEntity(MoodEntry entry) {
        if (entry == null) {
            return null;
        }
        return MoodEntryResponse.builder()
                .id(entry.getId())
                .userId(entry.getUser() != null ? entry.getUser().getId() : null)
                .moodScore(entry.getMoodScore())
                .note(entry.getNote())
                .timestamp(entry.getTimestamp())
                .tags(entry.getTags())
                .crisisAlert(false)
                .crisisMessage(null)
                .aiAvailable(true)
                .build();
    }
}
