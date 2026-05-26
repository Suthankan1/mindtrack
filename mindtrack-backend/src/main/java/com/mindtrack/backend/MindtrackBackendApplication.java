package com.mindtrack.backend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * MindTrack Backend — Spring Boot REST API for the MindTrack mental health platform. SDG 3 Good Health and Well-being.
 */
@EnableScheduling
@EnableAsync
@SpringBootApplication
public class MindtrackBackendApplication {

	public static void main(String[] args) {
		SpringApplication.run(MindtrackBackendApplication.class, args);
	}

}

