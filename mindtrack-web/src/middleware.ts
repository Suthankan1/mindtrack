import { withAuth } from "next-auth/middleware";

export default withAuth({
  pages: {
    signIn: "/login",
  },
});

export const config = {
  matcher: [
    "/dashboard/:path*",
    "/journal/:path*",
    "/insights/:path*",
    "/therapists/:path*",
    "/settings/:path*",
  ],
};
