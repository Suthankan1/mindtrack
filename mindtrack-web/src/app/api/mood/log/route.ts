import { NextRequest, NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/lib/auth";
import axios from "axios";

export async function POST(req: NextRequest) {
  try {
    const session = await getServerSession(authOptions);

    if (!session || !session.user?.accessToken) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const body = await req.json();

    const response = await axios.post(`${process.env.BACKEND_URL}/api/mood/log`, body, {
      headers: {
        Authorization: `Bearer ${session.user.accessToken}`,
        "Content-Type": "application/json",
      },
    });

    return NextResponse.json(response.data, { status: 201 });
  } catch (error: unknown) {
    const err = error as { response?: { data?: { message?: string } }; message?: string };
    const errMsg = err.response?.data?.message || err.message || "Failed to log mood";
    const errStatus = (err.response as { status?: number })?.status || 500;

    console.error("Error in POST /api/mood/log proxy:", errMsg);
    return NextResponse.json(
      { error: errMsg },
      { status: errStatus }
    );
  }
}
