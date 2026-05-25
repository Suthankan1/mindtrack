package com.mindtrack.backend.repository;

import com.mindtrack.backend.model.User;
import com.mindtrack.backend.model.UserPreference;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserPreferenceRepository extends JpaRepository<UserPreference, UUID> {
    Optional<UserPreference> findByUser(User user);
}
