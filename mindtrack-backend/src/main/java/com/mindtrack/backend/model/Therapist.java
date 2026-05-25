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

    @Column(columnDefinition = "TEXT", nullable = false)
    private String bio;

    @Column(nullable = false)
    private double rating;

    @Column(nullable = false)
    private String availability;

    @Column(name = "avatar_gradient", nullable = false)
    private String avatarGradient;

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "therapist_tags", joinColumns = @JoinColumn(name = "therapist_id"))
    @Column(name = "tag")
    private java.util.List<String> tags;
}
