import { LRUCache } from "lru-cache";

import { appStoreMetadata } from "@calcom/app-store/appStoreMetaData";
import { getAppFromSlug } from "@calcom/app-store/utils";
import getInstallCountPerApp from "@calcom/lib/apps/getInstallCountPerApp";
import { getAllDelegationCredentialsForUser } from "@calcom/lib/delegationCredential/server";
import type { UserAdminTeams } from "@calcom/lib/server/repository/user";
import prisma, { safeAppSelect, safeCredentialSelect } from "@calcom/prisma";
import { userMetadata } from "@calcom/prisma/zod-utils";
import type { AppFrontendPayload as App } from "@calcom/types/App";
import type { CredentialFrontendPayload as Credential } from "@calcom/types/Credential";

// Cache for app registry data
const APP_REGISTRY_CACHE = new LRUCache<string, any>({
  max: 100,
  ttl: 1000 * 60 * 5, // 5 minutes
});

export type TDependencyData = {
  name?: string;
  installed?: boolean;
}[];

/**
 * Get App metadata either using dirName or slug
 */
export async function getAppWithMetadata(app: { dirName: string } | { slug: string }) {
  // Convert appStoreMetadata object to array for searching
  const appMetadataArray = Object.values(appStoreMetadata);

  const appMetadata = appMetadataArray.find((metadata) => {
    if ("dirName" in app) {
      return metadata.dirName === app.dirName;
    }
    return metadata.slug === app.slug;
  });

  if (!appMetadata) {
    return null;
  }

  const { key, ...metadata } = appMetadata;
  return metadata;
}

/** Mainly to use in listings for the frontend, use in getStaticProps or getServerSideProps */
export async function getAppRegistry() {
  const cacheKey = "app-registry";
  const cached = APP_REGISTRY_CACHE.get(cacheKey);
  if (cached) {
    return cached;
  }

  try {
    const dbApps = await prisma.app.findMany({
      where: { enabled: true },
      select: { dirName: true, slug: true, categories: true, enabled: true, createdAt: true },
    });
    const apps = [] as App[];
    const installCountPerApp = await getInstallCountPerApp();
    for await (const dbapp of dbApps) {
      const app = await getAppWithMetadata(dbapp);
      if (!app) continue;
      // Skip if app isn't installed
      /* This is now handled from the DB */
      // if (!app.installed) return apps;
      app.createdAt = dbapp.createdAt.toISOString();
      apps.push({
        ...app,
        category: app.category || "other",
        installed:
          true /* All apps from DB are considered installed by default. @TODO: Add and filter our by `enabled` property */,
        installCount: installCountPerApp[dbapp.slug] || 0,
      });
    }

    APP_REGISTRY_CACHE.set(cacheKey, apps);
    return apps;
  } catch (error) {
    console.error("Error fetching app registry", error);
    return [];
  }
}

export async function getAppRegistryWithCredentials(userId: number, userAdminTeams: UserAdminTeams = []) {
  // Get teamIds to grab existing credentials

  const dbApps = await prisma.app.findMany({
    where: { enabled: true },
    select: {
      ...safeAppSelect,
      credentials: {
        where: { OR: [{ userId }, { teamId: { in: userAdminTeams } }] },
        select: safeCredentialSelect,
      },
    },
    orderBy: {
      credentials: {
        _count: "desc",
      },
    },
  });

  const user = await prisma.user.findUnique({
    where: {
      id: userId,
    },
    select: {
      email: true,
      id: true,
      metadata: true,
    },
  });

  const delegationCredentials = user
    ? await getAllDelegationCredentialsForUser({ user: { id: userId, email: user.email } })
    : [];

  const usersDefaultApp = userMetadata.parse(user?.metadata)?.defaultConferencingApp?.appSlug;
  const apps = [] as (App & {
    credentials: Credential[];
    isDefault?: boolean;
  })[];
  const installCountPerApp = await getInstallCountPerApp();
  for await (const dbapp of dbApps) {
    const delegationCredentialsForApp = delegationCredentials.filter(
      (credential) => credential.appId === dbapp.slug
    );
    const nonDelegationCredentialsForApp = dbapp.credentials;
    const allCredentials = [...delegationCredentialsForApp, ...nonDelegationCredentialsForApp];
    const app = await getAppWithMetadata(dbapp);
    if (!app) continue;
    // Skip if app isn't installed
    /* This is now handled from the DB */
    // if (!app.installed) return apps;
    app.createdAt = dbapp.createdAt.toISOString();
    let dependencyData: TDependencyData = [];
    if (app.dependencies) {
      dependencyData = app.dependencies.map((dependency) => {
        const dependencyInstalled = dbApps.some(
          (dbAppIterator) => dbAppIterator.credentials.length && dbAppIterator.slug === dependency
        );
        // If the app marked as dependency is simply deleted from the codebase, we can have the situation where App is marked installed in DB but we couldn't get the app.
        const dependencyName = getAppFromSlug(dependency)?.name;
        return { name: dependencyName, installed: dependencyInstalled };
      });
    }

    apps.push({
      ...app,
      categories: dbapp.categories,
      credentials: allCredentials,
      installed: true,
      installCount: installCountPerApp[dbapp.slug] || 0,
      isDefault: usersDefaultApp === dbapp.slug,
      ...(app.dependencies && { dependencyData }),
    });
  }

  return apps;
}
