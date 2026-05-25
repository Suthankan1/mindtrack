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
                    .specialty("Cognitive Behavioral Therapy (CBT)")
                    .location("New York, NY (Remote)")
                    .contactEmail("elara.vance@mindtrack.org")
                    .verified(true)
                    .bio("Specializes in restructuring cognitive patterns, treating anxiety disorders, and guiding emotional regulation through structured, evidence-based practices.")
                    .rating(4.9)
                    .availability("Available Tomorrow")
                    .avatarGradient("from-teal-400 to-emerald-500")
                    .tags(List.of("CBT", "Anxiety", "Depression", "Cognitive Patterns"))
                    .build(),
                Therapist.builder()
                    .name("Dr. Liam Sterling")
                    .specialty("Stress & Anxiety Specialist")
                    .location("New York, NY (Hybrid)")
                    .contactEmail("liam.sterling@mindtrack.org")
                    .verified(true)
                    .bio("Focuses on high-stress professionals, helping them manage panic states, burnout recovery, and emotional overwhelm with customized stress mitigation tools.")
                    .rating(4.8)
                    .availability("Available Now (Secure Call)")
                    .avatarGradient("from-cyan-400 to-indigo-500")
                    .tags(List.of("Stress", "Burnout", "Anxiety", "Crisis Support"))
                    .build(),
                Therapist.builder()
                    .name("Marcus Thorne, LCSW")
                    .specialty("Mindfulness & Somatic Integration")
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
                    .name("Dr. Aisha Rahman")
                    .specialty("Neurodiversity & ADHD Coaching")
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
                    .name("Elena Rostova")
                    .specialty("Somatic Experiencing & Trauma Recovery")
                    .location("Colombo (Remote)")
                    .contactEmail("elena.rostova@mindtrack.org")
                    .verified(true)
                    .bio("Focuses on releasing body-stored trauma. Utilizes somatic experiencing, nervous system regulation, and EMDR techniques for deep physiological alignment.")
                    .rating(4.7)
                    .availability("Available Wednesday")
                    .avatarGradient("from-rose-400 to-red-500")
                    .tags(List.of("Trauma", "Somatic", "EMDR", "Nervous System"))
                    .build(),
                Therapist.builder()
                    .name("David Kaelen")
                    .specialty("Emotional Regulation & Relationship Counseling")
                    .location("Mumbai (Remote)")
                    .contactEmail("david.kaelen@mindtrack.org")
                    .verified(true)
                    .bio("Guides individuals and partners in building emotional intelligence, overcoming communication breakdowns, and healing emotional attachment triggers.")
                    .rating(4.8)
                    .availability("Available Today (1 Slot)")
                    .avatarGradient("from-indigo-400 to-purple-600")
                    .tags(List.of("Relationships", "Emotional Regulation", "Communication", "Attachment"))
                    .build(),
                Therapist.builder()
                    .name("Dr. Sarah Jenkins")
                    .specialty("Depression & Mood Disorder Therapy")
                    .location("Colombo (Remote)")
                    .contactEmail("sarah.jenkins@mindtrack.org")
                    .verified(true)
                    .bio("Offers supportive psychotherapy and evidence-based interventions for persistent mood changes, emotional validation, and chronic depression recovery.")
                    .rating(4.9)
                    .availability("Available Friday")
                    .avatarGradient("from-emerald-400 to-teal-600")
                    .tags(List.of("Depression", "CBT", "Self-Care", "Mood"))
                    .build(),
                Therapist.builder()
                    .name("Dr. Michael Chang")
                    .specialty("Trauma & PTSD Specialist")
                    .location("New York, NY (In-Person)")
                    .contactEmail("michael.chang@mindtrack.org")
                    .verified(true)
                    .bio("Dedicated to assisting clients navigate complex PTSD, developmental trauma, and resilience building using cognitive restructuring and positive psychology.")
                    .rating(4.8)
                    .availability("Available Next Month")
                    .avatarGradient("from-blue-500 to-cyan-600")
                    .tags(List.of("Trauma", "PTSD", "EMDR", "Resilience"))
                    .build(),
                Therapist.builder()
                    .name("Priya Sharma")
                    .specialty("CBT & Anxiety Management")
                    .location("Mumbai (Hybrid)")
                    .contactEmail("priya.sharma@mindtrack.org")
                    .verified(true)
                    .bio("Passionate about behavioral activation and cognitive therapy for chronic panic attacks, anxiety states, and work-related performance pressure.")
                    .rating(4.9)
                    .availability("Available Today")
                    .avatarGradient("from-amber-400 to-red-500")
                    .tags(List.of("CBT", "Anxiety", "Panic Attacks", "Mindfulness"))
                    .build(),
                Therapist.builder()
                    .name("Dr. Oliver Bennett")
                    .specialty("Anxiety & OCD Therapy")
                    .location("New York, NY (Remote)")
                    .contactEmail("oliver.bennett@mindtrack.org")
                    .verified(true)
                    .bio("Specializes in Exposure and Response Prevention (ERP) and CBT for obsessive-compulsive behaviors, health anxiety, and social phobia.")
                    .rating(4.7)
                    .availability("Available Monday")
                    .avatarGradient("from-fuchsia-500 to-pink-600")
                    .tags(List.of("Anxiety", "OCD", "CBT", "ERP"))
                    .build()
            );
            therapistRepository.saveAll(therapists);
        }
    }
}
