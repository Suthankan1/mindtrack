package com.mindtrack.backend.repository;

import com.mindtrack.backend.model.CrisisResource;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface CrisisResourceRepository extends JpaRepository<CrisisResource, UUID> {
    List<CrisisResource> findByCountryIgnoreCase(String country);
}
