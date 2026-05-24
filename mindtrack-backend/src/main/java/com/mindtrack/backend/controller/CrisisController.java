package com.mindtrack.backend.controller;

import com.mindtrack.backend.model.CrisisResource;
import com.mindtrack.backend.repository.CrisisResourceRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * REST controller that exposes crisis support resources for MindTrack users.
 *
 * <p>Resources can optionally be filtered by country to surface locally relevant
 * helplines and emergency contacts. Endpoint is publicly accessible (no auth required)
 * so users in distress can always reach it.
 */
@RestController
@RequestMapping("/api/crisis")
public class CrisisController {

    private final CrisisResourceRepository crisisResourceRepository;

    /**
     * Constructs the {@code CrisisController} with the required repository.
     *
     * @param crisisResourceRepository JPA repository for crisis resource data
     */
    public CrisisController(CrisisResourceRepository crisisResourceRepository) {
        this.crisisResourceRepository = crisisResourceRepository;
    }

    /**
     * Returns a list of crisis support resources, optionally filtered by country.
     *
     * @param country optional ISO country name or code to filter results;
     *                if {@code null} or blank, all resources are returned
     * @return {@code 200 OK} with a list of {@link CrisisResource} entries
     */
    @GetMapping("/resources")
    public ResponseEntity<List<CrisisResource>> getResources(
            @RequestParam(value = "country", required = false) String country) {
        if (country == null || country.isBlank()) {
            return ResponseEntity.ok(crisisResourceRepository.findAll());
        }
        return ResponseEntity.ok(crisisResourceRepository.findByCountryIgnoreCase(country));
    }
}
