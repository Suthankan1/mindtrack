package com.mindtrack.backend.config;

import com.mindtrack.backend.model.CrisisResource;
import com.mindtrack.backend.model.Therapist;
import com.mindtrack.backend.repository.CrisisResourceRepository;
import com.mindtrack.backend.repository.TherapistRepository;
import com.mindtrack.backend.repository.CopingSessionRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
public class DataLoader implements CommandLineRunner {

    private final CrisisResourceRepository crisisResourceRepository;
    private final TherapistRepository therapistRepository;
    private final CopingSessionRepository copingSessionRepository;

    public DataLoader(
            CrisisResourceRepository crisisResourceRepository,
            TherapistRepository therapistRepository,
            CopingSessionRepository copingSessionRepository) {
        this.crisisResourceRepository = crisisResourceRepository;
        this.therapistRepository = therapistRepository;
        this.copingSessionRepository = copingSessionRepository;
    }

    @Override
    public void run(String... args) throws Exception {
        seedCrisisResources();
        seedTherapists();
    }

    private void seedCrisisResources() {
        if (crisisResourceRepository.count() == 0) {
            List<CrisisResource> resources = List.of(
                CrisisResource.builder()
                    .country("LK")
                    .lineName("Sumithrayo")
                    .phoneNumber("+94 11 2696583")
                    .website("https://www.sumithrayo.org")
                    .available24h(false)
                    .build(),
                CrisisResource.builder()
                    .country("IN")
                    .lineName("iCall")
                    .phoneNumber("9152987821")
                    .website("https://www.icallhelpline.org")
                    .available24h(false)
                    .build(),
                CrisisResource.builder()
                    .country("US")
                    .lineName("988 Suicide & Crisis Lifeline")
                    .phoneNumber("988")
                    .website("https://988lifeline.org")
                    .available24h(true)
                    .build(),
                CrisisResource.builder()
                    .country("GB")
                    .lineName("Samaritans")
                    .phoneNumber("116 123")
                    .website("https://www.samaritans.org")
                    .available24h(true)
                    .build(),
                CrisisResource.builder()
                    .country("GLOBAL")
                    .lineName("Befrienders International")
                    .phoneNumber("N/A")
                    .website("https://www.befrienders.org")
                    .available24h(true)
                    .build()
            );
            crisisResourceRepository.saveAll(resources);
        }
    }

    private void seedTherapists() {
        if (therapistRepository.count() == 0) {
            List<Therapist> therapists = List.of(
                Therapist.builder()
                    .name("Dr. Elara Vance")
                    .specialty("CBT")
                    .location("New York")
                    .contactEmail("elara.vance@mindtrack.org")
                    .verified(true)
                    .build(),
                Therapist.builder()
                    .name("Dr. Liam Sterling")
                    .specialty("Anxiety")
                    .location("Colombo")
                    .contactEmail("liam.sterling@mindtrack.org")
                    .verified(true)
                    .build(),
                Therapist.builder()
                    .name("Marcus Thorne, LCSW")
                    .specialty("CBT")
                    .location("Mumbai")
                    .contactEmail("marcus.thorne@mindtrack.org")
                    .verified(true)
                    .build(),
                Therapist.builder()
                    .name("Dr. Aisha Rahman")
                    .specialty("Depression")
                    .location("New York")
                    .contactEmail("aisha.rahman@mindtrack.org")
                    .verified(true)
                    .build(),
                Therapist.builder()
                    .name("Elena Rostova")
                    .specialty("Trauma")
                    .location("Colombo")
                    .contactEmail("elena.rostova@mindtrack.org")
                    .verified(true)
                    .build(),
                Therapist.builder()
                    .name("David Kaelen")
                    .specialty("Anxiety")
                    .location("Mumbai")
                    .contactEmail("david.kaelen@mindtrack.org")
                    .verified(true)
                    .build(),
                Therapist.builder()
                    .name("Dr. Sarah Jenkins")
                    .specialty("Depression")
                    .location("Colombo")
                    .contactEmail("sarah.jenkins@mindtrack.org")
                    .verified(true)
                    .build(),
                Therapist.builder()
                    .name("Dr. Michael Chang")
                    .specialty("Trauma")
                    .location("New York")
                    .contactEmail("michael.chang@mindtrack.org")
                    .verified(true)
                    .build(),
                Therapist.builder()
                    .name("Priya Sharma")
                    .specialty("CBT")
                    .location("Mumbai")
                    .contactEmail("priya.sharma@mindtrack.org")
                    .verified(true)
                    .build(),
                Therapist.builder()
                    .name("Dr. Oliver Bennett")
                    .specialty("Anxiety")
                    .location("New York")
                    .contactEmail("oliver.bennett@mindtrack.org")
                    .verified(true)
                    .build()
            );
            therapistRepository.saveAll(therapists);
        }
    }
}
