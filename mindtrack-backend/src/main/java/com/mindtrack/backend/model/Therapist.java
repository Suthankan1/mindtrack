package com.mindtrack.backend.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.UUID;

@Entity
@Table(name = "therapists")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class Therapist {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    @Column(columnDefinition = "UUID", updatable = false, nullable = false)
    private UUID id;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false)
    private String specialty;

    @Column(nullable = false)
    private String location;

    @Column(name = "contact_email", nullable = false)
    private String contactEmail;

    @Column(nullable = false)
    private boolean verified;

    @Column(columnDefinition = "TEXT DEFAULT ''", nullable = false)
    private String bio;

    @Column(columnDefinition = "float8 DEFAULT 0.0", nullable = false)
    private double rating;

    // columnDefinition includes a DEFAULT so PostgreSQL can backfill existing
    // null rows when Hibernate's ddl-auto=update runs ALTER TABLE ADD COLUMN.
    @Column(columnDefinition = "varchar(255) DEFAULT 'Available'", nullable = false)
    private String availability;

    @Column(name = "avatar_gradient", columnDefinition = "varchar(255) DEFAULT 'from-slate-500 to-slate-700'", nullable = false)
    private String avatarGradient;

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "therapist_tags", joinColumns = @JoinColumn(name = "therapist_id"))
    @Column(name = "tag")
    private java.util.List<String> tags;
}
