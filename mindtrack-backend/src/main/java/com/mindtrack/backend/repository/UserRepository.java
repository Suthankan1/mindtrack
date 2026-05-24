package com.mindtrack.backend.repository;

import com.mindtrack.backend.model.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Locale;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface UserRepository extends JpaRepository<User, UUID> {
    Optional<User> findByEmailIgnoreCase(String email);
    boolean existsByEmailIgnoreCase(String email);

    default Optional<User> findByEmail(String email) {
        return findByEmailIgnoreCase(normalizeEmail(email));
    }

    default boolean existsByEmail(String email) {
        return existsByEmailIgnoreCase(normalizeEmail(email));
    }

    private static String normalizeEmail(String email) {
        return email == null ? null : email.trim().toLowerCase(Locale.ROOT);
    }
}
