export interface MoodEntry {
  id: string;
  userId: string;
  moodScore: number;
  note: string;
  timestamp: string;
  tags: string[];
}

export interface UserStats {
  totalEntries: number;
  currentStreak: number;
  longestStreak: number;
  avgMoodScore: number;
  avgMoodScoreThisWeek: number;
  joinedDaysAgo: number;
}

declare global {
  // eslint-disable-next-line no-var
  var mockMoodEntries: MoodEntry[] | undefined;
}

const DEFAULT_MOCK_ENTRIES: MoodEntry[] = [
  {
    id: "mock-1",
    userId: "demo-user-1",
    moodScore: 5,
    note: "Woke up feeling incredibly refreshed. Had a fantastic morning jog and 15 mins of deep mindfulness.",
    timestamp: new Date(Date.now() - 1000 * 60 * 60 * 2).toISOString(), // 2 hours ago
    tags: ["Sleep", "Exercise", "Mindfulness"],
  },
  {
    id: "mock-2",
    userId: "demo-user-1",
    moodScore: 4,
    note: "Very productive design sprint session. Felt deeply in the flow state. Nutrition was clean.",
    timestamp: new Date(Date.now() - 1000 * 60 * 60 * 24 * 1 - 1000 * 60 * 60 * 4).toISOString(), // 1 day ago
    tags: ["Work", "Nutrition"],
  },
  {
    id: "mock-3",
    userId: "demo-user-1",
    moodScore: 4,
    note: "Had a great dinner with close friends. Caught up on life, laughed a lot. Social battery fully recharged.",
    timestamp: new Date(Date.now() - 1000 * 60 * 60 * 24 * 2 - 1000 * 60 * 60 * 6).toISOString(), // 2 days ago
    tags: ["Social"],
  },
  {
    id: "mock-4",
    userId: "demo-user-1",
    moodScore: 3,
    note: "Felt a bit lethargic and distracted in the afternoon. Sleep was slightly disrupted last night. Will focus on winding down early.",
    timestamp: new Date(Date.now() - 1000 * 60 * 60 * 24 * 3 - 1000 * 60 * 60 * 7).toISOString(), // 3 days ago
    tags: ["Sleep", "Work"],
  },
  {
    id: "mock-5",
    userId: "demo-user-1",
    moodScore: 2,
    note: "High stress with sudden production bugs. Felt slightly overwhelmed by the backlog. Need to schedule a proper breaks pattern.",
    timestamp: new Date(Date.now() - 1000 * 60 * 60 * 24 * 4 - 1000 * 60 * 60 * 9).toISOString(),
    tags: ["Work"],
  },
  {
    id: "mock-6",
    userId: "demo-user-1",
    moodScore: 4,
    note: "Mindfulness and yoga practice helped ground me after yesterday's sprint. Reclaimed control over my day.",
    timestamp: new Date(Date.now() - 1000 * 60 * 60 * 24 * 5 - 1000 * 60 * 60 * 3).toISOString(),
    tags: ["Mindfulness", "Exercise"],
  },
  {
    id: "mock-7",
    userId: "demo-user-1",
    moodScore: 5,
    note: "Spectacular workout session! Set a new personal best. Eating was perfectly balanced. High energy.",
    timestamp: new Date(Date.now() - 1000 * 60 * 60 * 24 * 6 - 1000 * 60 * 60 * 5).toISOString(),
    tags: ["Exercise", "Nutrition"],
  },
  {
    id: "mock-8",
    userId: "demo-user-1",
    moodScore: 4,
    note: "Excellent 8-hour restorative sleep. Woke up with zero brain fog. Had a solid morning planning block.",
    timestamp: new Date(Date.now() - 1000 * 60 * 60 * 24 * 7 - 1000 * 60 * 60 * 2).toISOString(),
    tags: ["Sleep", "Work"],
  },
  {
    id: "mock-9",
    userId: "demo-user-1",
    moodScore: 3,
    note: "Steady, quiet Wednesday. Just grinding through emails. Kept physical movement minimal, feeling okay.",
    timestamp: new Date(Date.now() - 1000 * 60 * 60 * 24 * 8 - 1000 * 60 * 60 * 6).toISOString(),
    tags: ["Work"],
  },
  {
    id: "mock-10",
    userId: "demo-user-1",
    moodScore: 4,
    note: "Nice evening stroll in the park. Socialized briefly. Felt a comforting sense of calm connection.",
    timestamp: new Date(Date.now() - 1000 * 60 * 60 * 24 * 9 - 1000 * 60 * 60 * 4).toISOString(),
    tags: ["Social", "Exercise"],
  },
  {
    id: "mock-11",
    userId: "demo-user-1",
    moodScore: 3,
    note: "Woke up to cold rain. Felt very cozy reading inside with tea. Focus was slightly lower but mood was peaceful.",
    timestamp: new Date(Date.now() - 1000 * 60 * 60 * 24 * 10 - 1000 * 60 * 60 * 8).toISOString(),
    tags: ["Mindfulness"],
  },
  {
    id: "mock-12",
    userId: "demo-user-1",
    moodScore: 5,
    note: "Fantastic start to the weekend! Clear head, went to a local farmer's market and cooked a nutrient-rich meal.",
    timestamp: new Date(Date.now() - 1000 * 60 * 60 * 24 * 11 - 1000 * 60 * 60 * 1).toISOString(),
    tags: ["Nutrition", "Sleep"],
  },
  {
    id: "mock-13",
    userId: "demo-user-1",
    moodScore: 4,
    note: "Slept in a bit. Long walks under the sun. Deeply relaxed and completely disconnected from work chats.",
    timestamp: new Date(Date.now() - 1000 * 60 * 60 * 24 * 12 - 1000 * 60 * 60 * 5).toISOString(),
    tags: ["Sleep", "Exercise"],
  },
  {
    id: "mock-14",
    userId: "demo-user-1",
    moodScore: 2,
    note: "Tired and a bit irritable today due to late-night screen time. Note to self: lock away phone at 10 PM.",
    timestamp: new Date(Date.now() - 1000 * 60 * 60 * 24 * 13 - 1000 * 60 * 60 * 10).toISOString(),
    tags: ["Sleep"],
  },
  {
    id: "mock-15",
    userId: "demo-user-1",
    moodScore: 4,
    note: "Cleaned up the workspace. A tidy environment immediately eased mental clutter. Feeling stable.",
    timestamp: new Date(Date.now() - 1000 * 60 * 60 * 24 * 14 - 1000 * 60 * 60 * 3).toISOString(),
    tags: ["Work", "Mindfulness"],
  }
];

export function initializeMockStore() {
  if (!global.mockMoodEntries) {
    global.mockMoodEntries = [...DEFAULT_MOCK_ENTRIES];
  }
}

export function getMockEntries(days: number = 30): MoodEntry[] {
  initializeMockStore();
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - days);
  
  return (global.mockMoodEntries || [])
    .filter(entry => new Date(entry.timestamp) >= cutoff)
    .sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime());
}

export function addMockEntry(moodScore: number, note: string, tags: string[]): MoodEntry {
  initializeMockStore();
  const newEntry: MoodEntry = {
    id: `mock-new-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
    userId: "demo-user-1",
    moodScore,
    note: note || "Logged moment of reflection.",
    timestamp: new Date().toISOString(),
    tags: tags || [],
  };
  global.mockMoodEntries = [newEntry, ...(global.mockMoodEntries || [])];
  return newEntry;
}

export function getMockStats(): UserStats {
  initializeMockStore();
  const entries = global.mockMoodEntries || [];
  const now = new Date();
  const sevenDaysAgo = new Date(now);
  sevenDaysAgo.setDate(now.getDate() - 7);

  const average = (items: MoodEntry[]) => {
    if (items.length === 0) return 0;
    const total = items.reduce((sum, entry) => sum + entry.moodScore, 0);
    return Math.round((total / items.length) * 100) / 100;
  };

  const loggedDates = new Set(
    entries.map((entry) => new Date(entry.timestamp).toISOString().slice(0, 10))
  );

  let currentStreak = 0;
  const cursor = new Date(now);
  while (loggedDates.has(cursor.toISOString().slice(0, 10))) {
    currentStreak += 1;
    cursor.setDate(cursor.getDate() - 1);
  }

  const sortedDates = Array.from(loggedDates).sort();
  let longestStreak = 0;
  let runningStreak = 0;
  let previousDate: Date | null = null;

  for (const dateString of sortedDates) {
    const date = new Date(`${dateString}T00:00:00.000Z`);
    if (
      previousDate &&
      Math.round((date.getTime() - previousDate.getTime()) / (1000 * 60 * 60 * 24)) === 1
    ) {
      runningStreak += 1;
    } else {
      runningStreak = 1;
    }

    longestStreak = Math.max(longestStreak, runningStreak);
    previousDate = date;
  }

  const weeklyEntries = entries.filter((entry) => new Date(entry.timestamp) >= sevenDaysAgo);

  return {
    totalEntries: entries.length,
    currentStreak,
    longestStreak,
    avgMoodScore: average(entries),
    avgMoodScoreThisWeek: average(weeklyEntries),
    joinedDaysAgo: 42,
  };
}
