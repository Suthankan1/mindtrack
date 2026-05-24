import { NextResponse } from "next/server";
import { getServerSession } from "next-auth/next";
import { authOptions } from "@/lib/auth";

export interface Therapist {
  id: string;
  name: string;
  specialty: string;
  location: string;
  bio: string;
  rating: number;
  availability: string;
  avatarGradient: string; // Sleek CSS linear gradients matching the UI
  tags: string[];
  email: string;
}

const THERAPISTS_DIRECTORY: Therapist[] = [
  {
    id: "1",
    name: "Dr. Elara Vance",
    specialty: "Cognitive Behavioral Therapy (CBT)",
    location: "San Francisco, CA (Remote)",
    bio: "Specializes in restructuring cognitive cognitive patterns, treating anxiety disorders, and guiding emotional regulation through structured, evidence-based practices.",
    rating: 4.9,
    availability: "Available Tomorrow",
    avatarGradient: "from-teal-400 to-emerald-500",
    tags: ["CBT", "Anxiety", "Depression", "Cognitive Patterns"],
    email: "elara.vance@mindtrack.org",
  },
  {
    id: "2",
    name: "Dr. Liam Sterling",
    specialty: "Stress & Anxiety Specialist",
    location: "New York, NY (Hybrid)",
    bio: "Focuses on high-stress professionals, helping them manage panic states, burnout recovery, and emotional overwhelm with customized stress mitigation tools.",
    rating: 4.8,
    availability: "Available Now (Secure Call)",
    avatarGradient: "from-cyan-400 to-indigo-500",
    tags: ["Stress", "Burnout", "Anxiety", "Crisis Support"],
    email: "liam.sterling@mindtrack.org",
  },
  {
    id: "3",
    name: "Marcus Thorne, LCSW",
    specialty: "Mindfulness & Somatic Integration",
    location: "Austin, TX (Remote)",
    bio: "Integrates Eastern mindfulness philosophies with Western clinical psychology. Specializes in grounding exercises, somatic regulation, and sensory decompression.",
    rating: 4.9,
    availability: "Available Thursday",
    avatarGradient: "from-amber-400 to-orange-500",
    tags: ["Mindfulness", "Somatic", "Meditation", "Stress"],
    email: "marcus.thorne@mindtrack.org",
  },
  {
    id: "4",
    name: "Dr. Aisha Rahman",
    specialty: "Neurodiversity & ADHD Coaching",
    location: "Seattle, WA (Remote)",
    bio: "Provides neurodiversity-affirming therapy. Specializes in executive dysfunction solutions, ADHD workspace structuring, and autistic fatigue recovery.",
    rating: 5.0,
    availability: "Available Next Week",
    avatarGradient: "from-purple-400 to-pink-500",
    tags: ["ADHD", "Neurodiversity", "Executive Function", "Autism"],
    email: "aisha.rahman@mindtrack.org",
  },
  {
    id: "5",
    name: "Elena Rostova",
    specialty: "Somatic Experiencing & Trauma Recovery",
    location: "Boston, MA (In-Person)",
    bio: "Focuses on releasing body-stored trauma. Utilizes somatic experiencing, nervous system regulation, and EMDR techniques for deep physiological alignment.",
    rating: 4.7,
    availability: "Available Wednesday",
    avatarGradient: "from-rose-400 to-red-500",
    tags: ["Trauma", "Somatic", "EMDR", "Nervous System"],
    email: "elena.rostova@mindtrack.org",
  },
  {
    id: "6",
    name: "David Kaelen",
    specialty: "Emotional Regulation & Relationship Counseling",
    location: "Denver, CO (Remote)",
    bio: "Guides individuals and partners in building emotional intelligence, overcoming communication breakdowns, and healing emotional attachment triggers.",
    rating: 4.8,
    availability: "Available Today (1 Slot)",
    avatarGradient: "from-indigo-400 to-purple-600",
    tags: ["Relationships", "Emotional Regulation", "Communication", "Attachment"],
    email: "david.kaelen@mindtrack.org",
  },
];

export async function GET() {
  try {
    const session = await getServerSession(authOptions);

    if (!session) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    return NextResponse.json(THERAPISTS_DIRECTORY);
  } catch (error: unknown) {
    console.error("Error in GET /api/therapists:", error);
    return NextResponse.json(
      { error: "Failed to load clinical guidance directories." },
      { status: 500 }
    );
  }
}
