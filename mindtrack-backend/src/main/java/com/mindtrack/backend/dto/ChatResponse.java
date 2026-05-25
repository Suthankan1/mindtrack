package com.mindtrack.backend.dto;

import com.mindtrack.backend.model.CrisisResource;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ChatResponse {
    private String reply;
    private List<String> suggestedFollowUps;

    @Builder.Default
    private boolean aiAvailable = true;

    @Builder.Default
    private boolean showCrisisResources = false;

    private List<CrisisResource> crisisResources;
}
