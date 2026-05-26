import { NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/lib/auth";
import axios from "axios";
import { backendUrl } from "@/lib/apiMode";

export const dynamic = "force-dynamic";

/**
 * DELETE /api/user/clear-data
 *
 * Server-side proxy route that forwards the destructive clear data request to the
 * Spring Boot backend at BACKEND_URL/api/user/clear-data. Attaches the
 * user's JWT as a Bearer token so the backend can authenticate the call.
 */
export async function DELETE() {
  try {
    const session = await getServerSession(authOptions);

    if (!session || !session.user?.accessToken) {
      return NextResponse.json({ error: "Unauthorized access detected" }, { status: 401 });
    }

    try {
      const url = backendUrl();
      const response = await axios.delete(
        `${url}/api/user/clear-data`,
        {
          headers: {
            Authorization: `Bearer ${session.user.accessToken}`,
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
        "Spring Boot backend offline or failed on clear data request:",
        backendError
      );
      return NextResponse.json(
        { error: "Backend service unavailable. Please try again." },
        { status: 503 }
      );
    }
  } catch (error: unknown) {
    const err = error as { message?: string };
    console.error("Error in clear-data endpoint:", err.message || error);
    return NextResponse.json(
      { error: err.message || "Failed to process database reset request" },
      { status: 500 }
    );
  }
}
