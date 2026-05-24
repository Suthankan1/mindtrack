package com.mindtrack.backend.controller;

import com.mindtrack.backend.dto.AuthResponse;
import com.mindtrack.backend.dto.LoginRequest;
import com.mindtrack.backend.dto.RegisterRequest;
import com.mindtrack.backend.model.User;
import com.mindtrack.backend.repository.UserRepository;
import com.mindtrack.backend.security.JwtTokenProvider;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.web.bind.annotation.*;

import java.util.Locale;

/**
 * REST controller that exposes authentication endpoints for MindTrack users.
 *
 * <p>Provides two public operations:
 * <ul>
 *   <li>{@code POST /api/auth/register} — create a new account and receive a JWT</li>
 *   <li>{@code POST /api/auth/login}    — authenticate with email/password and receive a JWT</li>
 * </ul>
 */
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider tokenProvider;
    private final AuthenticationManager authenticationManager;

    @Value("${jwt.expiration}")
    private long jwtExpirationInMs;

    /**
     * Constructs the {@code AuthController} with all required dependencies injected by Spring.
     *
     * @param userRepository        repository for user persistence
     * @param passwordEncoder       BCrypt password encoder
     * @param tokenProvider         JWT generation and validation utility
     * @param authenticationManager Spring Security authentication manager
     */
    public AuthController(
            UserRepository userRepository,
            PasswordEncoder passwordEncoder,
            JwtTokenProvider tokenProvider,
            AuthenticationManager authenticationManager) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.tokenProvider = tokenProvider;
        this.authenticationManager = authenticationManager;
    }

    /**
     * Registers a new MindTrack user account.
     *
     * <p>Validates that the email is not already in use, hashes the password,
     * persists the user, and returns a signed JWT along with basic account info.
     *
     * @param registerRequest the validated registration payload (email, password, anonymousMode)
     * @return {@code 201 Created} with an {@link AuthResponse} on success,
     *         or {@code 400 Bad Request} if the email is already taken
     */
    @PostMapping("/register")
    public ResponseEntity<?> registerUser(@Valid @RequestBody RegisterRequest registerRequest) {
        String email = normalizeEmail(registerRequest.getEmail());

        if (userRepository.existsByEmail(email)) {
            return ResponseEntity
                    .status(HttpStatus.BAD_REQUEST)
                    .body(new ErrorResponse("Email address is already in use"));
        }

        User user = User.builder()
                .email(email)
                .passwordHash(passwordEncoder.encode(registerRequest.getPassword()))
                .anonymousMode(registerRequest.isAnonymousMode())
                .build();

        User savedUser = userRepository.save(user);

        String jwt = tokenProvider.generateToken(savedUser.getEmail());

        AuthResponse authResponse = AuthResponse.builder()
                .accessToken(jwt)
                .expiresIn(jwtExpirationInMs)
                .userId(savedUser.getId())
                .email(savedUser.getEmail())
                .anonymousMode(savedUser.isAnonymousMode())
                .build();

        return ResponseEntity.status(HttpStatus.CREATED).body(authResponse);
    }

    /**
     * Authenticates an existing MindTrack user via email and password.
     *
     * <p>Delegates credential verification to Spring Security's {@link AuthenticationManager},
     * then issues a fresh JWT on success.
     *
     * @param loginRequest the validated login payload (email, password)
     * @return {@code 200 OK} with an {@link AuthResponse} on success,
     *         or {@code 401 Unauthorized} if credentials are invalid
     */
    @PostMapping("/login")
    public ResponseEntity<?> authenticateUser(@Valid @RequestBody LoginRequest loginRequest) {
        try {
            String email = normalizeEmail(loginRequest.getEmail());

            Authentication authentication = authenticationManager.authenticate(
                    new UsernamePasswordAuthenticationToken(
                            email,
                            loginRequest.getPassword()
                    )
            );

            SecurityContextHolder.getContext().setAuthentication(authentication);

            User user = userRepository.findByEmail(email)
                    .orElseThrow(() -> new BadCredentialsException("User not found"));

            String jwt = tokenProvider.generateToken(user.getEmail());

            AuthResponse authResponse = AuthResponse.builder()
                    .accessToken(jwt)
                    .expiresIn(jwtExpirationInMs)
                    .userId(user.getId())
                    .email(user.getEmail())
                    .anonymousMode(user.isAnonymousMode())
                    .build();

            return ResponseEntity.ok(authResponse);
        } catch (BadCredentialsException ex) {
            return ResponseEntity
                    .status(HttpStatus.UNAUTHORIZED)
                    .body(new ErrorResponse("Invalid email or password"));
        }
    }

    private String normalizeEmail(String email) {
        return email == null ? null : email.trim().toLowerCase(Locale.ROOT);
    }

    /**
     * Simple error response wrapper returned when authentication fails.
     */
    public static class ErrorResponse {
        private String message;

        /**
         * Creates an {@code ErrorResponse} with the given human-readable message.
         *
         * @param message a short description of the error
         */
        public ErrorResponse(String message) {
            this.message = message;
        }

        /**
         * Returns the error message.
         *
         * @return the error message string
         */
        public String getMessage() {
            return message;
        }

        /**
         * Sets the error message.
         *
         * @param message the new error message string
         */
        public void setMessage(String message) {
            this.message = message;
        }
    }
}
