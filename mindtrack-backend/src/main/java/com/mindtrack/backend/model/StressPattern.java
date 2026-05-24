package com.mindtrack.backend.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.UUID;

@Entity
@Table(name = "stress_patterns")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class StressPattern {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(columnDefinition = "UUID", updatable = false, nullable = false)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "weekly_average", nullable = false)
    private double weeklyAverage;

    @Column(name = "peak_stress_day")
    private String peakStressDay;

    @Column(name = "ai_insight", columnDefinition = "TEXT")
    private String aiInsight;

    @Column(name = "week_start_date", nullable = false)
    private LocalDate weekStartDate;

    @Column(name = "week_end_date", nullable = false)
    private LocalDate weekEndDate;

    @Column(name = "calculated_at", nullable = false)
    private LocalDateTime calculatedAt;
}
