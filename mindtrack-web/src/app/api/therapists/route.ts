import { NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/lib/auth";
import axios from "axios";
import { backendUrl } from "@/lib/apiMode";

export const dynamic = "force-dynamic";

/**
 * GET /api/therapists
 *
 * Proxies the request to the Spring Boot backend to fetch the verified list of 
 * therapist profiles. The user's active JWT is forwarded in the Authorization header.
 *
 * @returns 200 with an array of Therapist objects on success,
 *          401 if unauthorized,
 *          503 if the Spring Boot backend is unavailable,
 *          or 500 on other errors
 */
export async function GET() {
  try {
    const session = await getServerSession(authOptions);

    if (!session || !session.user?.accessToken) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    try {
      const url = backendUrl();
      const response = await axios.get(`${url}/api/therapists`, {
        headers: {
          Authorization: `Bearer ${session.user.accessToken}`,
        },
      });

      return NextResponse.json(response.data);
    } catch (backendError) {
      console.error("Therapist directory fetch failed:", backendError);
      return NextResponse.json(
        { error: "Failed to load therapist directory." },
        { status: 503 }
      );
    }
  } catch (error: unknown) {
    const err = error as { response?: { data?: { message?: string } }; message?: string };
    const errMsg = err.response?.data?.message || err.message || "Failed to load clinical guidance directories.";
    
    console.error("Error in GET /api/therapists proxy:", errMsg);
    return NextResponse.json(
      { error: errMsg },
      { status: 500 }
    );
  }
}
