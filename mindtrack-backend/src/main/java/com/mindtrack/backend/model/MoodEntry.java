package com.mindtrack.backend.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.hibernate.annotations.CreationTimestamp;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "mood_entries")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class MoodEntry {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(columnDefinition = "UUID", updatable = false, nullable = false)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "mood_score", nullable = false)
    private int moodScore;

    @Column(columnDefinition = "TEXT")
    private String note;

    @Column(nullable = false)
    private LocalDateTime timestamp;

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "mood_entry_tags", joinColumns = @JoinColumn(name = "mood_entry_id"))
    @Column(name = "tag")
    private List<String> tags;
}
