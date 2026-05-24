package com.mindtrack.backend.repository;

import com.mindtrack.backend.model.MoodEntry;
import com.mindtrack.backend.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

@Repository
public interface MoodEntryRepository extends JpaRepository<MoodEntry, UUID> {
    List<MoodEntry> findByUserAndTimestampBetweenOrderByTimestampDesc(User user, LocalDateTime start, LocalDateTime end);
    List<MoodEntry> findByUserAndTimestampAfterOrderByTimestampDesc(User user, LocalDateTime start);

    long countByUser(User user);

    @Query("SELECT AVG(m.moodScore) FROM MoodEntry m WHERE m.user = :user")
    Double findAvgMoodScoreByUser(@Param("user") User user);

    @Query("SELECT AVG(m.moodScore) FROM MoodEntry m WHERE m.user = :user AND m.timestamp >= :since")
    Double findAvgMoodScoreByUserSince(@Param("user") User user, @Param("since") LocalDateTime since);
}
