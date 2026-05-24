package com.mindtrack.backend.controller;

import com.mindtrack.backend.model.Therapist;
import com.mindtrack.backend.repository.TherapistRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/therapists")
public class TherapistController {

    private final TherapistRepository therapistRepository;

    public TherapistController(TherapistRepository therapistRepository) {
        this.therapistRepository = therapistRepository;
    }

    @GetMapping
    public ResponseEntity<List<Therapist>> getAllTherapists() {
        return ResponseEntity.ok(therapistRepository.findAll());
    }
}
