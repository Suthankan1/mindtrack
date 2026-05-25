package com.mindtrack.backend.service;

import com.mindtrack.backend.model.CrisisResource;
import com.mindtrack.backend.repository.CrisisResourceRepository;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.regex.Pattern;

/**
 * Service providing rule-based detection for high-risk mental health crises,
 * self-harm, immediate danger, and domestic/physical abuse emergencies.
 */
@Service
public class MentalHealthSafetyService {

    private final CrisisResourceRepository crisisResourceRepository;

    // Compiled regex patterns for lightweight, fast rule detection
    private static final Pattern HIGH_RISK_PATTERN = Pattern.compile(
        "\\b(suicid\\w*|kill\\s+myself|kill\\s+my\\s+self|end(ing)?\\s+my\\s+life|end(ing)?\\s+it\\s+all|want\\s+to\\s+die|wanna\\s+die|committing\\s+suicide)\\b|" +
        "\\b(self-harm|self\\s+harm|cut(ting)?\\s+myself|hurt(ing)?\\s+myself|mutilat\\w*)\\b|" +
        "\\b(overdose|overdosing|swallow(ing)?\\s+pills|take\\s+all\\s+my\\s+pills|taking\\s+all\\s+my\\s+pills|jump(ing)?\\s+off|jump(ing)?\\s+from|hang(ing)?\\s+myself)\\b|" +
        "\\b(domestic\\s+abuse|domestic\\s+violence|being\\s+abused|someone\\s+(is\\s+)?hurting\\s+me|physically\\s+abus(e|ed|ing)|sexual\\s+abus(e|ed|ing)|sexual\\s+assault|immediate\\s+danger|emergency\\s+help)\\b",
        Pattern.CASE_INSENSITIVE
    );

    public MentalHealthSafetyService(CrisisResourceRepository crisisResourceRepository) {
        this.crisisResourceRepository = crisisResourceRepository;
    }

    /**
     * Checks if the message content contains high-risk suicide, self-harm, or emergency/abuse terms.
     *
     * @param text the message text to inspect
     * @return {@code true} if high-risk signals are found, {@code false} otherwise
     */
    public boolean isHighRisk(String text) {
        if (text == null || text.isBlank()) {
            return false;
        }
        return HIGH_RISK_PATTERN.matcher(text).find();
    }

    /**
     * Returns a compassionate, crisis-safe response that informs the user they are not alone,
     * avoids diagnosis, encourages immediate emergency help if in imminent danger, and
     * clarifies the automated non-monitored nature of the app.
     *
     * @return crisis-safe fallback text
     */
    public String getCrisisSafeMessage() {
        return "It sounds like you're going through a very difficult time right now, and I want to make sure you are safe. " +
               "Please know that you are not alone and there is support available. MindTrack is an automated companion and " +
               "cannot monitor or respond to emergencies. If you are in immediate danger, please contact your local " +
               "emergency services (like 911 or your local equivalent) or reach out to a trusted professional right away. " +
               "You can also connect with one of the free, confidential crisis support services listed below.";
    }

    /**
     * Fetches all registered crisis resources from the database.
     *
     * @return list of crisis resources
     */
    public List<CrisisResource> getCrisisResources() {
        return crisisResourceRepository.findAll();
    }
}
