import React from "react";
import InsightsPage from "@/app/dashboard/insights/page";
import DashboardLayout from "@/app/dashboard/layout";

export default function TopLevelInsightsRoute() {
  return (
    <DashboardLayout>
      <InsightsPage />
    </DashboardLayout>
  );
}
