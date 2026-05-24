package com.mindtrack.backend.repository;

import com.mindtrack.backend.model.Therapist;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.UUID;

@Repository
public interface TherapistRepository extends JpaRepository<Therapist, UUID> {
}
