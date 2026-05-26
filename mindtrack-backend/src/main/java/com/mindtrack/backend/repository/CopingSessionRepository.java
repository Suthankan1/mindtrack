package com.mindtrack.backend.repository;

import com.mindtrack.backend.model.CopingSession;
import com.mindtrack.backend.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface CopingSessionRepository extends JpaRepository<CopingSession, UUID> {
    List<CopingSession> findByUserOrderByCompletedAtDesc(User user);
    long countByUser(User user);
    long countByUserAndCompletedAtAfter(User user, java.time.LocalDateTime since);
}
