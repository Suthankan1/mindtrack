package com.mindtrack.backend.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.mindtrack.backend.dto.LoginRequest;
import com.mindtrack.backend.dto.RegisterRequest;
import com.mindtrack.backend.model.User;
import com.mindtrack.backend.repository.MoodEntryRepository;
import com.mindtrack.backend.repository.StreakRepository;
import com.mindtrack.backend.repository.StressPatternRepository;
import com.mindtrack.backend.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.hamcrest.Matchers.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
public class AuthControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private UserRepository userRepository;

    @Autowired
    private MoodEntryRepository moodEntryRepository;

    @Autowired
    private StreakRepository streakRepository;

    @Autowired
    private StressPatternRepository stressPatternRepository;

    @Autowired
    private PasswordEncoder passwordEncoder;

    @Autowired
    private ObjectMapper objectMapper;

    @BeforeEach
    void setUp() {
        stressPatternRepository.deleteAll();
        streakRepository.deleteAll();
        moodEntryRepository.deleteAll();
        userRepository.deleteAll();
    }

    @Test
    void registerUser_Success() throws Exception {
        RegisterRequest request = new RegisterRequest();
        request.setEmail("user@example.com");
        request.setPassword("password123");
        request.setAnonymousMode(true);

        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.accessToken", notNullValue()))
                .andExpect(jsonPath("$.tokenType", is("Bearer")))
                .andExpect(jsonPath("$.email", is("user@example.com")))
                .andExpect(jsonPath("$.anonymousMode", is(true)))
                .andExpect(jsonPath("$.userId", notNullValue()));
    }

    @Test
    void registerUser_DuplicateEmail() throws Exception {
        User existingUser = User.builder()
                .email("duplicate@example.com")
                .passwordHash(passwordEncoder.encode("existingPass"))
                .anonymousMode(false)
                .build();
        userRepository.save(existingUser);

        RegisterRequest request = new RegisterRequest();
        request.setEmail("duplicate@example.com");
        request.setPassword("password123");
        request.setAnonymousMode(true);

        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message", is("Email address is already in use")));
    }

    @Test
    void registerUser_ValidationErrors() throws Exception {
        RegisterRequest request = new RegisterRequest();
        request.setEmail("invalid-email");
        request.setPassword("123"); // Too short password

        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.error", is("Validation Failed")))
                .andExpect(jsonPath("$.errors.email", is("Please provide a valid email address")))
                .andExpect(jsonPath("$.errors.password", is("Password must be at least 6 characters")));
    }

    @Test
    void loginUser_Success() throws Exception {
        User user = User.builder()
                .email("testlogin@example.com")
                .passwordHash(passwordEncoder.encode("secretPass"))
                .anonymousMode(false)
                .build();
        userRepository.save(user);

        LoginRequest request = new LoginRequest();
        request.setEmail("testlogin@example.com");
        request.setPassword("secretPass");

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.accessToken", notNullValue()))
                .andExpect(jsonPath("$.email", is("testlogin@example.com")))
                .andExpect(jsonPath("$.anonymousMode", is(false)));
    }

    @Test
    void loginUser_Failure() throws Exception {
        User user = User.builder()
                .email("testlogin@example.com")
                .passwordHash(passwordEncoder.encode("secretPass"))
                .anonymousMode(false)
                .build();
        userRepository.save(user);

        LoginRequest request = new LoginRequest();
        request.setEmail("testlogin@example.com");
        request.setPassword("wrongPass");

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.message", is("Invalid email or password")));
    }
}
