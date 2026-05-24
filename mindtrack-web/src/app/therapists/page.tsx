import React from "react";
import TherapistsPage from "@/app/dashboard/therapists/page";
import DashboardLayout from "@/app/dashboard/layout";

export default function TopLevelTherapistsRoute() {
  return (
    <DashboardLayout>
      <TherapistsPage />
    </DashboardLayout>
  );
}
