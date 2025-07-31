"use client";

import { useReducer } from "react";

import { AppList, type HandleDisconnect } from "@calcom/features/apps/components/AppList";
import type { UpdateUsersDefaultConferencingAppParams } from "@calcom/features/apps/components/AppSetDefaultLinkDialog";
import DisconnectIntegrationModal from "@calcom/features/apps/components/DisconnectIntegrationModal";
import type { RemoveAppParams } from "@calcom/features/apps/components/DisconnectIntegrationModal";
import { SkeletonLoader } from "@calcom/features/apps/components/SkeletonLoader";
import type { BulkUpdatParams } from "@calcom/features/eventtypes/components/BulkEditDefaultForEventsModal";
import { useLocale } from "@calcom/lib/hooks/useLocale";
import { AppCategories } from "@calcom/prisma/enums";
import { trpc } from "@calcom/trpc/react";
import { Button } from "@calcom/ui/components/button";
import { EmptyScreen } from "@calcom/ui/components/empty-screen";
import type { Icon } from "@calcom/ui/components/icon";
import { ShellSubHeading } from "@calcom/ui/components/layout";
import { showToast } from "@calcom/ui/components/toast";

import { QueryCell } from "@lib/QueryCell";

import { CalendarListContainer } from "@components/apps/CalendarListContainer";
import InstalledAppsLayout from "@components/apps/layouts/InstalledAppsLayout";

interface IntegrationsContainerProps {
  variant?: AppCategories;
  exclude?: AppCategories[];
  handleDisconnect: HandleDisconnect;
}

const IntegrationsContainer = ({ variant, exclude, handleDisconnect }: IntegrationsContainerProps) => {
  const { t } = useLocale();
  const utils = trpc.useUtils();

  // Optimize: Use a single query with better caching
  const query = trpc.viewer.apps.integrations.useQuery(
    {
      variant,
      exclude,
      onlyInstalled: true,
      includeTeamInstalledApps: true,
    },
    {
      staleTime: 5 * 60 * 1000, // Cache for 5 minutes
      cacheTime: 10 * 60 * 1000, // Keep in cache for 10 minutes
    }
  );

  // Optimize: Use a single query for default conferencing app with caching
  const { data: defaultConferencingApp } = trpc.viewer.apps.getUsersDefaultConferencingApp.useQuery(
    undefined,
    {
      staleTime: 5 * 60 * 1000, // Cache for 5 minutes
      cacheTime: 10 * 60 * 1000, // Keep in cache for 10 minutes
    }
  );

  const updateDefaultAppMutation = trpc.viewer.apps.updateUserDefaultConferencingApp.useMutation();

  const updateLocationsMutation = trpc.viewer.eventTypes.bulkUpdateToDefaultLocation.useMutation();

  // Optimize: Use a single query for event types with caching
  const { data: eventTypesQueryData, isFetching: isEventTypesFetching } =
    trpc.viewer.eventTypes.bulkEventFetch.useQuery(undefined, {
      staleTime: 5 * 60 * 1000, // Cache for 5 minutes
      cacheTime: 10 * 60 * 1000, // Keep in cache for 10 minutes
    });

  const handleUpdateUserDefaultConferencingApp = ({
    appSlug,
    appLink,
    onSuccessCallback,
    onErrorCallback,
  }: UpdateUsersDefaultConferencingAppParams) => {
    updateDefaultAppMutation.mutate(
      { appSlug, appLink },
      {
        onSuccess: () => {
          showToast("Default app updated successfully", "success");
          utils.viewer.apps.getUsersDefaultConferencingApp.invalidate();
          onSuccessCallback();
        },
        onError: (error) => {
          showToast(`Error: ${error.message}`, "error");
          onErrorCallback();
        },
      }
    );
  };

  const handleBulkUpdateDefaultLocation = ({ eventTypeIds, callback }: BulkUpdatParams) => {
    updateLocationsMutation.mutate(
      {
        eventTypeIds,
      },
      {
        onSuccess: () => {
          utils.viewer.apps.getUsersDefaultConferencingApp.invalidate();
          callback();
        },
      }
    );
  };

  const handleConnectDisconnectIntegrationMenuToggle = () => {
    utils.viewer.apps.integrations.invalidate();
  };

  const handleBulkEditDialogToggle = () => {
    utils.viewer.apps.getUsersDefaultConferencingApp.invalidate();
  };

  // TODO: Refactor and reuse getAppCategories?
  const emptyIcon: Record<AppCategories, React.ComponentProps<typeof Icon>["name"]> = {
    calendar: "calendar",
    conferencing: "video",
    automation: "share-2",
    analytics: "chart-bar",
    payment: "credit-card",
    other: "grid-3x3",
    web3: "credit-card", // deprecated
    video: "video", // deprecated
    messaging: "mail",
    crm: "contact",
  };

  return (
    <QueryCell
      query={query}
      customLoader={<SkeletonLoader />}
      success={({ data }) => {
        if (!data.items.length) {
          return (
            <EmptyScreen
              Icon="grid-3x3"
              headline={t("no_apps", { category: variant || "other" })}
              description={t("no_apps_description", { category: variant || "other" })}
              buttonText={t("browse_apps")}
              buttonOnClick={() => {
                window.location.href = variant ? `/apps/categories/${variant}` : "/apps";
              }}
              buttonRaw={
                <Button
                  data-testid="add-apps"
                  href={variant ? `/apps/categories/${variant}` : "/apps"}
                  color="secondary"
                  StartIcon="plus">
                  {t("add")}
                </Button>
              }
            />
          );
        }
        return (
          <div className="border-subtle rounded-md border p-7">
            <ShellSubHeading
              title={t(variant || "other")}
              subtitle={t(`installed_app_${variant || "other"}_description`)}
              className="mb-6"
              actions={
                <Button
                  data-testid="add-apps"
                  href={variant ? `/apps/categories/${variant}` : "/apps"}
                  color="secondary"
                  StartIcon="plus">
                  {t("add")}
                </Button>
              }
            />

            <AppList
              handleDisconnect={handleDisconnect}
              data={data}
              variant={variant}
              defaultConferencingApp={defaultConferencingApp}
              handleUpdateUserDefaultConferencingApp={handleUpdateUserDefaultConferencingApp}
              handleBulkUpdateDefaultLocation={handleBulkUpdateDefaultLocation}
              isBulkUpdateDefaultLocationPending={updateDefaultAppMutation.isPending}
              eventTypes={eventTypesQueryData?.eventTypes}
              isEventTypesFetching={isEventTypesFetching}
              handleConnectDisconnectIntegrationMenuToggle={handleConnectDisconnectIntegrationMenuToggle}
              handleBulkEditDialogToggle={handleBulkEditDialogToggle}
            />
          </div>
        );
      }}
    />
  );
};

type ModalState = {
  isOpen: boolean;
  credentialId: null | number;
  teamId?: number;
};

type PageProps = {
  category: AppCategories;
};

export default function InstalledApps({ category }: PageProps) {
  const { t } = useLocale();
  const utils = trpc.useUtils();
  const categoryList: AppCategories[] = Object.values(AppCategories).filter((category) => {
    // Exclude calendar and other from categoryList, we handle those slightly differently below
    return !(category in { other: null, calendar: null });
  });

  const [data, updateData] = useReducer(
    (data: ModalState, partialData: Partial<ModalState>) => ({ ...data, ...partialData }),
    {
      isOpen: false,
      credentialId: null,
    }
  );

  const handleModelClose = () => {
    updateData({ isOpen: false, credentialId: null });
  };

  const handleDisconnect = (credentialId: number, app: string, teamId?: number) => {
    updateData({ isOpen: true, credentialId, teamId });
  };

  const deleteCredentialMutation = trpc.viewer.credentials.delete.useMutation();

  const handleRemoveApp = ({ credentialId, teamId, callback }: RemoveAppParams) => {
    deleteCredentialMutation.mutate(
      { id: credentialId, teamId },
      {
        onSuccess: () => {
          showToast(t("app_removed_successfully"), "success");
          callback();
          utils.viewer.apps.integrations.invalidate();
          utils.viewer.calendars.connectedCalendars.invalidate();
        },
        onError: () => {
          showToast(t("error_removing_app"), "error");
          callback();
        },
      }
    );
  };

  return (
    <>
      <InstalledAppsLayout heading={t("installed_apps")} subtitle={t("manage_your_connected_apps")}>
        {categoryList.includes(category) && (
          <IntegrationsContainer handleDisconnect={handleDisconnect} variant={category} />
        )}
        {category === "calendar" && <CalendarListContainer />}
        {category === "other" && (
          <IntegrationsContainer
            handleDisconnect={handleDisconnect}
            variant={category}
            exclude={[...categoryList, "calendar"]}
          />
        )}
      </InstalledAppsLayout>
      <DisconnectIntegrationModal
        handleModelClose={handleModelClose}
        isOpen={data.isOpen}
        credentialId={data.credentialId}
        teamId={data.teamId}
        handleRemoveApp={handleRemoveApp}
      />
    </>
  );
}
