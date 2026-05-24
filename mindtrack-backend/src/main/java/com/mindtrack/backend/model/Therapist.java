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
}
