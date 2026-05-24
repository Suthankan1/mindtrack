package com.mindtrack.backend;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class MindtrackBackendApplication {

	public static void main(String[] args) {
		SpringApplication.run(MindtrackBackendApplication.class, args);
	}

}

