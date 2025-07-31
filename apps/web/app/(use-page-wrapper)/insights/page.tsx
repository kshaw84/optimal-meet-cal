import { _generateMetadata } from "app/_utils";
import { unstable_cache } from "next/cache";
import { cookies, headers } from "next/headers";

import { getServerSession } from "@calcom/features/auth/lib/getServerSession";
import prisma from "@calcom/prisma";

import { buildLegacyRequest } from "@lib/buildLegacyCtx";

import InsightsPage from "~/insights/insights-view";

export const generateMetadata = async () =>
  await _generateMetadata(
    (t) => t("insights"),
    (t) => t("insights_subtitle"),
    undefined,
    undefined,
    "/insights"
  );

const getCachedUserTimezone = unstable_cache(
  async (userId: number) => {
    try {
      const user = await prisma.user.findUnique({
        where: { id: userId },
        select: { timeZone: true },
      });
      return user?.timeZone || "UTC";
    } catch (error) {
      console.error("Error fetching cached user timezone", { userId, error });
      return "UTC";
    }
  },
  undefined,
  { revalidate: 3600, tags: ["user.timezone"] } // Cache for 1 hour
);

const ServerPage = async () => {
  const session = await getServerSession({ req: buildLegacyRequest(await headers(), await cookies()) });

  const timeZone = await getCachedUserTimezone(session?.user.id ?? -1);

  return <InsightsPage timeZone={timeZone} />;
};

export default ServerPage;
