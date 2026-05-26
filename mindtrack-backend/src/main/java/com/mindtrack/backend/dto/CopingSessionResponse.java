package com.mindtrack.backend.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.mindtrack.backend.model.CopingSession;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;
import java.util.UUID;

@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CopingSessionResponse {
    private UUID id;
    private UUID userId;
    private String type;
    @JsonProperty("durationSeconds")
    private int durationSeconds;
    private LocalDateTime completedAt;

    public static CopingSessionResponse fromEntity(CopingSession session) {
        if (session == null) {
            return null;
        }
        return CopingSessionResponse.builder()
                .id(session.getId())
                .userId(session.getUser() != null ? session.getUser().getId() : null)
                .type(session.getType())
                .durationSeconds(session.getDurationSeconds())
                .completedAt(session.getCompletedAt())
                .build();
    }
}
