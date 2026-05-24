import NextAuth from "next-auth";
import { authOptions } from "@/lib/auth";

/**
 * NextAuth.js catch-all route handler.
 *
 * Delegates all GET and POST requests under /api/auth/* to the NextAuth
 * handler configured in {@link authOptions}. This includes sign-in, sign-out,
 * session retrieval, and callback handling for the credentials provider
 * backed by the Spring Boot authentication API.
 */
const handler = NextAuth(authOptions);

export { handler as GET, handler as POST };
