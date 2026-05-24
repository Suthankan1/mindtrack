package com.mindtrack.backend.repository;

import com.mindtrack.backend.model.StressPattern;
import com.mindtrack.backend.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface StressPatternRepository extends JpaRepository<StressPattern, UUID> {
    List<StressPattern> findByUserOrderByWeekStartDateDesc(User user);
}
