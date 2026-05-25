package com.mindtrack.backend.service;

import com.mindtrack.backend.model.CrisisResource;
import com.mindtrack.backend.repository.CrisisResourceRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.Arrays;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class MentalHealthSafetyServiceTest {

    private CrisisResourceRepository crisisResourceRepository;
    private MentalHealthSafetyService safetyService;

    @BeforeEach
    void setUp() {
        crisisResourceRepository = mock(CrisisResourceRepository.class);
        safetyService = new MentalHealthSafetyService(crisisResourceRepository);
    }

    @Test
    void isHighRisk_withSuicideIdeation_returnsTrue() {
        assertTrue(safetyService.isHighRisk("I want to commit suicide"));
        assertTrue(safetyService.isHighRisk("should I kill myself?"));
        assertTrue(safetyService.isHighRisk("I want to end my life now"));
        assertTrue(safetyService.isHighRisk("i want to die"));
        assertTrue(safetyService.isHighRisk("ending it all tonight"));
    }

    @Test
    void isHighRisk_withSelfHarm_returnsTrue() {
        assertTrue(safetyService.isHighRisk("I started cutting myself"));
        assertTrue(safetyService.isHighRisk("how to self-harm safely"));
        assertTrue(safetyService.isHighRisk("I want to hurt myself"));
    }

    @Test
    void isHighRisk_withImmediateDanger_returnsTrue() {
        assertTrue(safetyService.isHighRisk("I am going to overdose"));
        assertTrue(safetyService.isHighRisk("about to swallow pills"));
        assertTrue(safetyService.isHighRisk("I will jump off bridge"));
    }

    @Test
    void isHighRisk_withAbuseAndEmergency_returnsTrue() {
        assertTrue(safetyService.isHighRisk("my partner is physically abusing me"));
        assertTrue(safetyService.isHighRisk("someone is hurting me at home"));
        assertTrue(safetyService.isHighRisk("domestic violence help"));
        assertTrue(safetyService.isHighRisk("I need emergency help right now"));
    }

    @Test
    void isHighRisk_withSafeExpressions_returnsFalse() {
        assertFalse(safetyService.isHighRisk("I had a hard day at work"));
        assertFalse(safetyService.isHighRisk("feeling a bit stressed and tired"));
        assertFalse(safetyService.isHighRisk("I want to eat something nice"));
        assertFalse(safetyService.isHighRisk(null));
        assertFalse(safetyService.isHighRisk("   "));
    }

    @Test
    void getCrisisSafeMessage_returnsSupportiveMessage() {
        String msg = safetyService.getCrisisSafeMessage();
        assertNotNull(msg);
        assertTrue(msg.contains("safe"));
        assertTrue(msg.contains("not alone"));
        assertTrue(msg.contains("911"));
    }

    @Test
    void getCrisisResources_callsRepository() {
        CrisisResource res = CrisisResource.builder()
                .country("United States")
                .lineName("988 Suicide & Crisis Lifeline")
                .phoneNumber("988")
                .website("https://988lifeline.org")
                .available24h(true)
                .build();

        when(crisisResourceRepository.findAll()).thenReturn(Arrays.asList(res));

        List<CrisisResource> results = safetyService.getCrisisResources();
        assertEquals(1, results.size());
        assertEquals("988 Suicide & Crisis Lifeline", results.get(0).getLineName());
        verify(crisisResourceRepository, times(1)).findAll();
    }
}
