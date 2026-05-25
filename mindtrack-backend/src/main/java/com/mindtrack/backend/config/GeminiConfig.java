package com.mindtrack.backend.config;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.reactive.function.client.WebClient;

@Configuration
public class GeminiConfig {

    @Bean
    public WebClient geminiWebClient() {
        return WebClient.builder()
                .baseUrl("https://generativelanguage.googleapis.com")
                .codecs(configurer -> configurer.defaultCodecs().maxInMemorySize(2 * 1024 * 1024))
                .build();
    }
}
