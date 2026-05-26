import { NextResponse } from "next/server";
import axios from "axios";
import { backendUrl } from "@/lib/apiMode";

export const dynamic = "force-dynamic";

/**
 * GET /api/health
 *
 * Proxies the public Spring Boot health check. No auth or secrets
 * are exposed — only the backend's own response payload is forwarded.
 */
export async function GET() {
  try {
    const url = backendUrl();
    const response = await axios.get(`${url}/api/health`, {
      timeout: 5000,
    });
    return NextResponse.json(response.data);
  } catch (error) {
    // Backend unreachable — return a degraded status response.
    console.error("Health check: Spring Boot backend unreachable:", error);
    return NextResponse.json(
      {
        status: "DOWN",
        app: "MindTrack",
        sdg: "3 - Good Health and Well-being",
        aiEnabled: false,
      },
      { status: 503 }
    );
  }
}
