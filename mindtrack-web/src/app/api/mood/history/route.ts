import { NextRequest, NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/lib/auth";
import axios from "axios";

export async function GET(req: NextRequest) {
  try {
    const session = await getServerSession(authOptions);

    if (!session || !session.user?.accessToken) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    const { searchParams } = new URL(req.url);
    const days = searchParams.get("days") || "30";

    const response = await axios.get(`${process.env.BACKEND_URL}/api/mood/history`, {
      params: { days },
      headers: {
        Authorization: `Bearer ${session.user.accessToken}`,
      },
    });

    return NextResponse.json(response.data);
  } catch (error: unknown) {
    const err = error as { response?: { data?: { message?: string } }; message?: string; responseStatus?: number };
    const errMsg = err.response?.data?.message || err.message || "Failed to fetch mood history";
    const errStatus = (err.response as { status?: number })?.status || 500;
    
    console.error("Error in GET /api/mood/history proxy:", errMsg);
    return NextResponse.json(
      { error: errMsg },
      { status: errStatus }
    );
  }
}
