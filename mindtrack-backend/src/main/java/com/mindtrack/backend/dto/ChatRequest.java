package com.mindtrack.backend.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ChatRequest {

    @NotBlank(message = "Message cannot be blank")
    private String message;

    @Size(max = 10, message = "Conversation history cannot exceed 10 messages")
    @Valid
    private List<ChatMessageDto> conversationHistory;

    @Valid
    private MoodContextDto moodContext;
}
