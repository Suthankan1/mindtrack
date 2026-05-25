import { NextRequest, NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/lib/auth";
import axios from "axios";
import { isDemoToken, backendUrl } from "@/lib/apiMode";

export const dynamic = "force-dynamic";

/**
 * POST /api/user/change-password
 *
 * Server-side proxy route that forwards the password-change request to the
 * Spring Boot backend at BACKEND_URL/api/user/change-password. Attaches the
 * user's JWT as a Bearer token so the backend can authenticate the call.
 *
 * Resolves immediately with mock success if the user is in developer demo mode.
 */
export async function POST(req: NextRequest) {
  try {
    const session = await getServerSession(authOptions);

    if (!session || !session.user?.accessToken) {
      return NextResponse.json({ error: "Unauthorized access detected" }, { status: 401 });
    }

    const { currentPassword, newPassword } = await req.json();

    // Basic request body validation
    if (!currentPassword || !newPassword) {
      return NextResponse.json(
        { error: "Current password and new password are required fields." },
        { status: 400 }
      );
    }

    if (newPassword.length < 8) {
      return NextResponse.json(
        { error: "New password must be at least 8 characters long." },
        { status: 400 }
      );
    }

    if (currentPassword === newPassword) {
      return NextResponse.json(
        { error: "New password cannot be identical to your current password." },
        { status: 400 }
      );
    }

    // Handle developer demo session instantly without bothering the backend
    if (isDemoToken(session.user.accessToken)) {
      return NextResponse.json(
        { message: "Credentials modified successfully in the secure database." },
        { status: 200 }
      );
    }

    try {
      const url = backendUrl();
      const response = await axios.post(
        `${url}/api/user/change-password`,
        { currentPassword, newPassword },
        {
          headers: {
            Authorization: `Bearer ${session.user.accessToken}`,
            "Content-Type": "application/json",
          },
        }
      );

      return NextResponse.json(response.data, { status: response.status });
    } catch (backendError) {
      if (axios.isAxiosError(backendError) && backendError.response) {
        return NextResponse.json(backendError.response.data, {
          status: backendError.response.status,
        });
      }
      console.error(
        "Spring Boot backend offline or failed on password update:",
        backendError
      );
      return NextResponse.json(
        { error: "Bad Gateway: Spring Boot backend is offline or unavailable." },
        { status: 502 }
      );
    }
  } catch (error: unknown) {
    const err = error as { message?: string };
    console.error("Error in change-password endpoint:", err.message || error);
    return NextResponse.json(
      { error: err.message || "Failed to process security update" },
      { status: 500 }
    );
  }
}
