import { NextRequest, NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/lib/auth";
import axios from "axios";
import { backendUrl } from "@/lib/apiMode";

export const dynamic = "force-dynamic";

/**
 * POST /api/user/change-password
 *
 * Server-side proxy route that forwards the password-change request to the
 * Spring Boot backend at BACKEND_URL/api/user/change-password. Attaches the
 * user's JWT as a Bearer token so the backend can authenticate the call.
 */
export async function POST(req: NextRequest) {
  try {
    const session = await getServerSession(authOptions);

    if (!session || !session.user?.accessToken) {
      return NextResponse.json({ error: "Unauthorized access detected" }, { status: 401 });
    }

    const { currentPassword, newPassword } = await req.json();

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
        { error: "Backend service unavailable. Please try again." },
        { status: 503 }
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
