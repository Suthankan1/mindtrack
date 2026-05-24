package com.mindtrack.backend.controller;

import com.mindtrack.backend.model.CrisisResource;
import com.mindtrack.backend.repository.CrisisResourceRepository;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/crisis")
public class CrisisController {

    private final CrisisResourceRepository crisisResourceRepository;

    public CrisisController(CrisisResourceRepository crisisResourceRepository) {
        this.crisisResourceRepository = crisisResourceRepository;
    }

    @GetMapping("/resources")
    public ResponseEntity<List<CrisisResource>> getResources(
            @RequestParam(value = "country", required = false) String country) {
        if (country == null || country.isBlank()) {
            return ResponseEntity.ok(crisisResourceRepository.findAll());
        }
        return ResponseEntity.ok(crisisResourceRepository.findByCountryIgnoreCase(country));
    }
}
