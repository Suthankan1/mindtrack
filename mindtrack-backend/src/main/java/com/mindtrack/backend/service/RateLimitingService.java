package com.mindtrack.backend.service;

import io.github.bucket4j.Bandwidth;
import io.github.bucket4j.Bucket;
import io.github.bucket4j.Refill;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/**
 * In-memory rate limiting service using Bucket4j.
 * Enforces a maximum of 5 mood logs per hour per user.
 */
@Service
public class RateLimitingService {

    private static final int MAX_REQUESTS_PER_HOUR = 5;
    private final Map<UUID, Bucket> buckets = new ConcurrentHashMap<>();

    /**
     * Returns the rate-limiting bucket for the given user, creating one on first access.
     */
    private Bucket resolveBucket(UUID userId) {
        return buckets.computeIfAbsent(userId, id -> createNewBucket());
    }

    /**
     * Attempt to consume one token for the given user.
     *
     * @return true if the request is permitted, false if rate limit is exceeded.
     */
    public boolean tryConsume(UUID userId) {
        return resolveBucket(userId).tryConsume(1);
    }

    private Bucket createNewBucket() {
        Refill refill = Refill.greedy(MAX_REQUESTS_PER_HOUR, Duration.ofHours(1));
        Bandwidth limit = Bandwidth.classic(MAX_REQUESTS_PER_HOUR, refill);
        return Bucket.builder()
                .addLimit(limit)
                .build();
    }
}
