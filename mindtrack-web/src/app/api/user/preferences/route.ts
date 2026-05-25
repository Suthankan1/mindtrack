import { NextRequest, NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/lib/auth";
import axios from "axios";
import { backendUrl } from "@/lib/apiMode";

export const dynamic = "force-dynamic";

/**
 * GET /api/user/preferences
 *
 * Forwards preference retrieval to Spring Boot.
 */
export async function GET() {
  try {
    const session = await getServerSession(authOptions);

    if (!session || !session.user?.accessToken) {
      return NextResponse.json({ error: "Unauthorized access detected" }, { status: 401 });
    }

    try {
      const url = backendUrl();
      const response = await axios.get(`${url}/api/user/preferences`, {
        headers: {
          Authorization: `Bearer ${session.user.accessToken}`,
        },
      });

      return NextResponse.json(response.data);
    } catch (backendError) {
      console.error(
        "Spring Boot backend offline or failed on preferences fetch:",
        backendError
      );
      return NextResponse.json(
        { error: "Backend service unavailable. Please try again." },
        { status: 503 }
      );
    }
  } catch (error: unknown) {
    const err = error as { message?: string };
    console.error("Error in GET /api/user/preferences:", err.message || error);
    return NextResponse.json(
      { error: err.message || "Failed to fetch preferences" },
      { status: 500 }
    );
  }
}

/**
 * PUT /api/user/preferences
 *
 * Forwards preference updates to Spring Boot.
 */
export async function PUT(req: NextRequest) {
  try {
    const session = await getServerSession(authOptions);

    if (!session || !session.user?.accessToken) {
      return NextResponse.json({ error: "Unauthorized access detected" }, { status: 401 });
    }

    const body = await req.json();

    try {
      const url = backendUrl();
      const response = await axios.put(`${url}/api/user/preferences`, body, {
        headers: {
          Authorization: `Bearer ${session.user.accessToken}`,
          "Content-Type": "application/json",
        },
      });

      return NextResponse.json(response.data, { status: response.status });
    } catch (backendError) {
      if (axios.isAxiosError(backendError) && backendError.response) {
        return NextResponse.json(backendError.response.data, {
          status: backendError.response.status,
        });
      }
      console.error(
        "Spring Boot backend offline or failed on preferences update:",
        backendError
      );
      return NextResponse.json(
        { error: "Backend service unavailable. Please try again." },
        { status: 503 }
      );
    }
  } catch (error: unknown) {
    const err = error as { message?: string };
    console.error("Error in PUT /api/user/preferences:", err.message || error);
    return NextResponse.json(
      { error: err.message || "Failed to update preferences" },
      { status: 500 }
    );
  }
}
