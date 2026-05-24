import { create } from "zustand";

interface UIState {
  isSidebarOpen: boolean;
  activeNav: string;
  setSidebarOpen: (isOpen: boolean) => void;
  toggleSidebar: () => void;
  setActiveNav: (nav: string) => void;
}

export const useUIStore = create<UIState>((set) => ({
  isSidebarOpen: false,
  activeNav: "Dashboard",
  setSidebarOpen: (isOpen) => set({ isSidebarOpen: isOpen }),
  toggleSidebar: () => set((state) => ({ isSidebarOpen: !state.isSidebarOpen })),
  setActiveNav: (nav) => set({ activeNav: nav }),
}));

export interface MoodEntry {
  id: string;
  moodValue: number; // 1 to 5
  note: string;
  createdAt: string;
}

interface MoodState {
  entries: MoodEntry[];
  addEntry: (moodValue: number, note: string) => void;
  clearEntries: () => void;
}

export const useMoodStore = create<MoodState>((set) => ({
  entries: [
    { id: "1", moodValue: 5, note: "Feeling absolutely fantastic, very productive day!", createdAt: "2026-05-24T09:00:00.000Z" },
    { id: "2", moodValue: 3, note: "A bit tired in the afternoon, but doing ok.", createdAt: "2026-05-23T14:30:00.000Z" },
    { id: "3", moodValue: 4, note: "Great workout session, felt energized.", createdAt: "2026-05-22T19:00:00.000Z" },
    { id: "4", moodValue: 2, note: "Stressful meetings, feeling slightly overwhelmed.", createdAt: "2026-05-21T11:00:00.000Z" },
    { id: "5", moodValue: 4, note: "Had a nice dinner with friends, very relaxed.", createdAt: "2026-05-20T20:15:00.000Z" },
  ],
  addEntry: (moodValue, note) => set((state) => ({
    entries: [
      {
        id: Math.random().toString(36).substring(7),
        moodValue,
        note,
        createdAt: new Date().toISOString(),
      },
      ...state.entries,
    ],
  })),
  clearEntries: () => set({ entries: [] }),
}));
