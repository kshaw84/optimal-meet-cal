import { cookies, headers } from "next/headers";
import { redirect } from "next/navigation";

import { getServerSession } from "@calcom/features/auth/lib/getServerSession";

import { buildLegacyRequest } from "@lib/buildLegacyCtx";

const RedirectPage = async () => {
  const session = await getServerSession({ req: buildLegacyRequest(await headers(), await cookies()) });

  if (!session?.user?.id) {
    // Check if we're already on an auth page to prevent redirect loops
    const headersList = await headers();
    const pathname = headersList.get("x-pathname") || "";

    if (pathname.startsWith("/auth/") || pathname.startsWith("/login")) {
      // If we're already on an auth page, don't redirect again
      return null;
    }

    redirect("/auth/login");
  }

  // If user is authenticated, redirect to event types
  redirect("/event-types");
};

export default RedirectPage;
