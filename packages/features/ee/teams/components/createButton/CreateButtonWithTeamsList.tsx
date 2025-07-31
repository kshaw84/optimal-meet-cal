"use client";

import { trpc } from "@calcom/trpc/react";

import type { CreateBtnProps, Option } from "./CreateButton";
import { CreateButton } from "./CreateButton";

export function CreateButtonWithTeamsList(
  props: Omit<CreateBtnProps, "options"> & {
    onlyShowWithTeams?: boolean;
    onlyShowWithNoTeams?: boolean;
    isAdmin?: boolean;
    includeOrg?: boolean;
  }
) {
  const { includeOrg, onlyShowWithTeams, onlyShowWithNoTeams, isAdmin, ...restProps } = props;

  const query = trpc.viewer.loggedInViewerRouter.teamsAndUserProfilesQuery.useQuery({
    includeOrg,
  });
  if (!query.data) return null;

  const teamsAndUserProfiles: Option[] = query.data
    .filter((profile) => !profile.readOnly)
    .map((profile) => {
      return {
        teamId: profile.teamId,
        label: profile.name || profile.slug,
        image: profile.image,
        slug: profile.slug,
      };
    });

  if (isAdmin) {
    teamsAndUserProfiles.push({
      platform: true,
      label: "Platform",
      image: null,
      slug: null,
      teamId: null,
    });
  }

  if (onlyShowWithTeams && teamsAndUserProfiles.length < 2) return null;

  if (onlyShowWithNoTeams && teamsAndUserProfiles.length > 1) return null;

  return <CreateButton {...restProps} options={teamsAndUserProfiles} />;
}
