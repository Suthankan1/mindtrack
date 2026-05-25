import { NextResponse } from "next/server";
import axios from "axios";
import { backendUrl } from "@/lib/apiMode";

export const dynamic = "force-dynamic";

/**
 * GET /api/crisis/resources
 *
 * Proxies the crisis support resources query to the Spring Boot backend
 * with optional country-based filtering. Publicly accessible.
 */
export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const country = searchParams.get("country");

    const url = backendUrl();
    const response = await axios.get(`${url}/api/crisis/resources`, {
      params: country ? { country } : {},
    });

    return NextResponse.json(response.data);
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    console.error("Error in GET /api/crisis/resources proxy:", errorMessage);

    // Minimal high-quality, static fallback resources in case backend is offline
    const fallbackResources = [
      {
        id: "fallback-988",
        country: "United States",
        lineName: "988 Suicide & Crisis Lifeline",
        phoneNumber: "988",
        website: "https://988lifeline.org",
        available24h: true
      },
      {
        id: "fallback-text",
        country: "United States",
        lineName: "Crisis Text Line",
        phoneNumber: "741741",
        website: "https://www.crisistextline.org",
        available24h: true
      }
    ];

    return NextResponse.json(fallbackResources);
  }
}
