import { NextRequest, NextResponse } from "next/server";
import axios from "axios";

/**
 * POST /api/register
 *
 * Proxies the registration request to the Spring Boot backend at
 * BACKEND_URL/api/auth/register. Keeps the backend URL server-side only
 * and avoids CORS issues from the browser.
 */
export async function POST(req: NextRequest) {
  try {
    const body = await req.json();

    const response = await axios.post(
      `${process.env.BACKEND_URL}/api/auth/register`,
      body,
      {
        headers: { "Content-Type": "application/json" },
      }
    );

    return NextResponse.json(response.data, { status: response.status });
  } catch (error) {
    if (axios.isAxiosError(error) && error.response) {
      return NextResponse.json(error.response.data, {
        status: error.response.status,
      });
    }
    console.error("Registration proxy error:", error);
    return NextResponse.json(
      { message: "Unable to connect to the server. Please try again later." },
      { status: 502 }
    );
  }
}
