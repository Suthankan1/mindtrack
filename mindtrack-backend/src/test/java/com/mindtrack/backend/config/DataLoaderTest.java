package com.mindtrack.backend.config;

import com.mindtrack.backend.repository.CrisisResourceRepository;
import com.mindtrack.backend.repository.TherapistRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.mockito.Mockito.*;

class DataLoaderTest {

    private CrisisResourceRepository crisisResourceRepository;
    private TherapistRepository therapistRepository;
    private DataLoader dataLoader;

    @BeforeEach
    void setUp() {
        crisisResourceRepository = mock(CrisisResourceRepository.class);
        therapistRepository = mock(TherapistRepository.class);
        dataLoader = new DataLoader(crisisResourceRepository, therapistRepository);
    }

    @Test
    void seedTherapists_whenEmpty_insertsTherapists() throws Exception {
        // Arrange
        when(therapistRepository.count()).thenReturn(0L);
        when(crisisResourceRepository.count()).thenReturn(0L);

        // Act
        dataLoader.run();

        // Assert
        verify(therapistRepository, times(1)).saveAll(anyList());
        verify(therapistRepository, never()).deleteAllInBatch();
    }

    @Test
    void seedTherapists_whenNotEmpty_doesNotWipeOrDuplicate() throws Exception {
        // Arrange
        when(therapistRepository.count()).thenReturn(5L);
        when(crisisResourceRepository.count()).thenReturn(5L);

        // Act
        dataLoader.run();

        // Assert
        verify(therapistRepository, never()).saveAll(anyList());
        verify(therapistRepository, never()).deleteAllInBatch();
    }
}
