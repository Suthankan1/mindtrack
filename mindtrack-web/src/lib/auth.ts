import { NextAuthOptions } from "next-auth";
import CredentialsProvider from "next-auth/providers/credentials";
import axios from "axios";
import { isDemoModeEnabled, backendUrl } from "./apiMode";

const normalizeEmail = (value: string) => value.trim().toLowerCase();

export const authOptions: NextAuthOptions = {
  providers: [
    CredentialsProvider({
      name: "Credentials",
      credentials: {
        email: { label: "Email", type: "email" },
        password: { label: "Password", type: "password" }
      },
      async authorize(credentials) {
        if (!credentials?.email || !credentials?.password) {
          throw new Error("Missing email or password");
        }

        const email = normalizeEmail(credentials.email);

        try {
          if (isDemoModeEnabled() && email === "demo@mindtrack.com" && credentials.password === "demo123") {
            return {
              id: "demo-user-1",
              email,
              name: "Demo User",
              accessToken: "demo-mock-jwt-token-data",
            };
          }

          const url = backendUrl();
          const response = await axios.post(`${url}/api/auth/login`, {
            email,
            password: credentials.password,
          });

          const user = response.data;
          
          if (user && user.accessToken) {
            return {
              id: user.userId,
              email: user.email,
              name: user.email,
              accessToken: user.accessToken,
            };
          }
          return null;
        } catch (error) {
          if (axios.isAxiosError(error)) {
            console.error("Auth error:", error.response?.data || error.message);
            throw new Error(error.response?.data?.message || "Invalid credentials");
          }
          console.error("Auth error:", error);
          throw new Error("Invalid credentials");
        }
      }
    })
  ],
  callbacks: {
    async jwt({ token, user }) {
      if (user) {
        token.accessToken = (user as { accessToken?: string }).accessToken;
        token.role = (user as { role?: string }).role;
      }
      return token;
    },
    async session({ session, token }) {
      if (session.user) {
        session.user.accessToken = token.accessToken;
        session.user.role = token.role;
      }
      return session;
    }
  },
  pages: {
    signIn: "/login",
    error: "/login",
  },
  session: {
    strategy: "jwt",
  },
  secret: process.env.NEXTAUTH_SECRET,
};
