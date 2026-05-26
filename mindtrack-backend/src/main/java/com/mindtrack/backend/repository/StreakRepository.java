package com.mindtrack.backend.repository;

import com.mindtrack.backend.model.Streak;
import com.mindtrack.backend.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface StreakRepository extends JpaRepository<Streak, UUID> {
    Optional<Streak> findByUser(User user);

    @Transactional
    void deleteByUser(User user);
}
