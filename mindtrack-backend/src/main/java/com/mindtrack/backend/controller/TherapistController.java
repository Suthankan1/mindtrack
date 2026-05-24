package com.mindtrack.backend.controller;

import com.mindtrack.backend.model.Therapist;
import com.mindtrack.backend.repository.TherapistRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

/**
 * REST controller for the MindTrack therapist directory.
 *
 * <p>Exposes a single endpoint that returns the full list of seeded therapist
 * profiles for display in the web and mobile clinician directory screens.
 */
@RestController
@RequestMapping("/api/therapists")
public class TherapistController {

    private final TherapistRepository therapistRepository;

    /**
     * Constructs the {@code TherapistController} with the required repository.
     *
     * @param therapistRepository JPA repository for therapist profile data
     */
    public TherapistController(TherapistRepository therapistRepository) {
        this.therapistRepository = therapistRepository;
    }

    /**
     * Returns all therapist profiles in the MindTrack clinician directory.
     *
     * @return {@code 200 OK} with a list of all {@link Therapist} entities
     */
    @GetMapping
    public ResponseEntity<List<Therapist>> getAllTherapists() {
        return ResponseEntity.ok(therapistRepository.findAll());
    }
}
