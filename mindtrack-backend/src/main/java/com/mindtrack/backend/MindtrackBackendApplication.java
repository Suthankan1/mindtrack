package com.mindtrack.backend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableAsync;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
@EnableAsync
/**
 * MindTrack Backend — Spring Boot REST API for the MindTrack mental health platform. SDG 3 Good Health and Well-being.
 */
public class MindtrackBackendApplication {

	public static void main(String[] args) {
		SpringApplication.run(MindtrackBackendApplication.class, args);
	}

}

