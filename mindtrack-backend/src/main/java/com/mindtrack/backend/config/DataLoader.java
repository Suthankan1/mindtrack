package com.mindtrack.backend.config;

import com.mindtrack.backend.model.CrisisResource;
import com.mindtrack.backend.model.Therapist;
import com.mindtrack.backend.repository.CrisisResourceRepository;
import com.mindtrack.backend.repository.TherapistRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
public class DataLoader implements CommandLineRunner {

    private final CrisisResourceRepository crisisResourceRepository;
    private final TherapistRepository therapistRepository;

    public DataLoader(
            CrisisResourceRepository crisisResourceRepository,
            TherapistRepository therapistRepository) {
        this.crisisResourceRepository = crisisResourceRepository;
        this.therapistRepository = therapistRepository;
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
                    .location("New York, NY (Remote)")
                    .contactEmail("elara.vance@mindtrack.org")
                    .verified(true)
                    .bio("Specializes in restructuring cognitive patterns, treating anxiety disorders, and guiding emotional regulation through structured, evidence-based practices.")
                    .rating(4.9)
                    .availability("Available Tomorrow")
                    .avatarGradient("from-teal-400 to-emerald-500")
                    .tags(List.of("CBT", "Anxiety", "Depression"))
                    .build(),
                Therapist.builder()
                    .name("Dr. Aisha Rahman")
                    .specialty("ADHD & Neurodiversity")
                    .location("New York, NY (Remote)")
                    .contactEmail("aisha.rahman@mindtrack.org")
                    .verified(true)
                    .bio("Provides neurodiversity-affirming therapy. Specializes in executive dysfunction solutions, ADHD workspace structuring, and autistic fatigue recovery.")
                    .rating(5.0)
                    .availability("Available Next Week")
                    .avatarGradient("from-purple-400 to-pink-500")
                    .tags(List.of("ADHD", "Neurodiversity", "Executive Function", "Autism"))
                    .build(),
                Therapist.builder()
                    .name("Marcus Thorne, LCSW")
                    .specialty("Mindfulness & Somatic")
                    .location("Mumbai (Hybrid)")
                    .contactEmail("marcus.thorne@mindtrack.org")
                    .verified(true)
                    .bio("Integrates Eastern mindfulness philosophies with Western clinical psychology. Specializes in grounding exercises, somatic regulation, and sensory decompression.")
                    .rating(4.9)
                    .availability("Available Thursday")
                    .avatarGradient("from-amber-400 to-orange-500")
                    .tags(List.of("Mindfulness", "Somatic", "Meditation", "Stress"))
                    .build(),
                Therapist.builder()
                    .name("Dr. Priya Sharma")
                    .specialty("Somatic Experiencing")
                    .location("Colombo")
                    .contactEmail("priya.sharma@mindtrack.org")
                    .verified(true)
                    .bio("Passionate about somatic regulation and cognitive therapy for chronic panic attacks, anxiety states, and work-related performance pressure.")
                    .rating(4.9)
                    .availability("Available Today")
                    .avatarGradient("from-amber-400 to-red-500")
                    .tags(List.of("Somatic", "Trauma", "CBT"))
                    .build(),
                Therapist.builder()
                    .name("Dr. James Wei")
                    .specialty("ADHD Coaching")
                    .location("New York")
                    .contactEmail("james.wei@mindtrack.org")
                    .verified(true)
                    .bio("Supports attention regulation, habit design, and mindfulness-based routines for clients balancing anxiety, executive function, and daily focus challenges.")
                    .rating(4.8)
                    .availability("Available Monday")
                    .avatarGradient("from-cyan-400 to-indigo-500")
                    .tags(List.of("ADHD", "Mindfulness", "Anxiety"))
                    .build()
            );

            therapistRepository.saveAll(therapists);
        }
    }
}
