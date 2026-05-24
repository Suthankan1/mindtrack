import { NextAuthOptions } from "next-auth";
import CredentialsProvider from "next-auth/providers/credentials";
import axios from "axios";

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

        // Demo fallback for instant developer verification
        if (credentials.email === "demo@mindtrack.com" && credentials.password === "demo123") {
          return {
            id: "demo-user-1",
            email: "demo@mindtrack.com",
            name: "Alex Carter",
            token: "demo-mock-jwt-token-data",
            role: "ADMIN",
          };
        }

        try {
          const response = await axios.post(`${process.env.BACKEND_URL}/api/auth/login`, {
            email: credentials.email,
            password: credentials.password,
          });

          const user = response.data;
          
          if (user && (user.token || user.accessToken)) {
            return {
              id: user.id || user.email,
              email: user.email,
              name: user.name || user.username || "User",
              token: user.token || user.accessToken,
              role: user.role || "USER",
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
        token.accessToken = (user as { token?: string }).token;
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
