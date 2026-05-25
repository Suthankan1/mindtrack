package com.mindtrack.backend.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.UUID;

@Entity
@Table(name = "user_preferences")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class UserPreference {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(columnDefinition = "UUID", updatable = false, nullable = false)
    private UUID id;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    @Column(name = "theme_mode", nullable = false)
    private String themeMode;

    @Column(name = "reminder_enabled", nullable = false)
    private boolean reminderEnabled;

    @Column(name = "reminder_time", nullable = false)
    private String reminderTime;

    @Column(name = "default_coping_technique")
    private String defaultCopingTechnique;

    @Column(name = "privacy_mode", nullable = false)
    private String privacyMode;
}
