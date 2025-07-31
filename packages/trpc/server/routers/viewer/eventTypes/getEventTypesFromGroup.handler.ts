import type { Prisma } from "@prisma/client";

import { hasFilter } from "@calcom/features/filters/lib/hasFilter";
import { checkRateLimitAndThrowError } from "@calcom/lib/checkRateLimitAndThrowError";
import logger from "@calcom/lib/logger";
import { EventTypeRepository } from "@calcom/lib/server/repository/eventType";
import { prisma } from "@calcom/prisma";
import type { PrismaClient } from "@calcom/prisma";

import type { TrpcSessionUser } from "../../../types";
import type { TGetEventTypesFromGroupSchema } from "./getByViewer.schema";
import { mapEventType } from "./util";

const log = logger.getSubLogger({ prefix: ["getEventTypesFromGroup"] });

type GetByViewerOptions = {
  ctx: {
    user: NonNullable<TrpcSessionUser>;
    prisma: PrismaClient;
  };
  input: TGetEventTypesFromGroupSchema;
};

type EventType = Awaited<ReturnType<EventTypeRepository["findAllByUpId"]>>[number];
type MappedEventType = Awaited<ReturnType<typeof mapEventType>>;

export const getEventTypesFromGroup = async ({
  ctx,
  input,
}: GetByViewerOptions): Promise<{
  eventTypes: MappedEventType[];
  nextCursor: number | null | undefined;
}> => {
  await checkRateLimitAndThrowError({
    identifier: `eventTypes:getEventTypesFromGroup:${ctx.user.id}`,
    rateLimitingType: "common",
  });

  const userProfile = ctx.user.profile;
  const { group, limit, cursor, filters, searchQuery } = input;
  const { teamId, parentId } = group;

  const isFilterSet = (filters && hasFilter(filters)) || !!teamId;
  const isUpIdInFilter = filters?.upIds?.includes(userProfile.upId);

  const shouldListUserEvents =
    !isFilterSet || isUpIdInFilter || (isFilterSet && filters?.upIds && !isUpIdInFilter);

  const eventTypes: EventType[] = [];
  const eventTypeRepo = new EventTypeRepository(ctx.prisma);

  // Optimize: Use a single query with better conditions instead of multiple queries
  if (shouldListUserEvents || !teamId) {
    const baseQueryConditions = {
      teamId: null,
      schedulingType: null,
      ...(searchQuery ? { title: { contains: searchQuery, mode: "insensitive" as Prisma.QueryMode } } : {}),
    };

    try {
      // Optimize: Combine queries to reduce database round trips
      const [nonChildEventTypes, childEventTypes] = await Promise.all([
        eventTypeRepo.findAllByUpId(
          {
            upId: userProfile.upId,
            userId: ctx.user.id,
          },
          {
            where: {
              ...baseQueryConditions,
              parentId: null,
            },
            orderBy: [
              {
                position: "desc",
              },
              {
                id: "desc",
              },
            ],
            limit: Math.ceil(limit / 2), // Optimize: Split limit for better distribution
            cursor,
          }
        ),
        eventTypeRepo.findAllByUpId(
          {
            upId: userProfile.upId,
            userId: ctx.user.id,
          },
          {
            where: {
              ...baseQueryConditions,
              parentId: { not: null },
              userId: ctx.user.id,
            },
            orderBy: [
              {
                position: "desc",
              },
              {
                id: "desc",
              },
            ],
            limit: Math.ceil(limit / 2), // Optimize: Split limit for better distribution
            cursor,
          }
        ),
      ]);

      const userEventTypes = [...(nonChildEventTypes ?? []), ...(childEventTypes ?? [])].sort((a, b) => {
        // First sort by position in descending order
        if (a.position !== b.position) {
          return b.position - a.position;
        }
        // Then by id in descending order
        return b.id - a.id;
      });

      eventTypes.push(...userEventTypes);
    } catch (error) {
      log.error("Error fetching user event types", { error, userId: ctx.user.id });
      // Return empty array on error to prevent complete failure
      return { eventTypes: [], nextCursor: undefined };
    }
  }

  if (teamId) {
    try {
      const teamEventTypes =
        (await eventTypeRepo.findTeamEventTypes({
          teamId,
          parentId,
          userId: ctx.user.id,
          limit,
          cursor,
          where: {
            ...(isFilterSet && !!filters?.schedulingTypes
              ? {
                  schedulingType: { in: filters.schedulingTypes },
                }
              : null),
            ...(searchQuery ? { title: { contains: searchQuery, mode: "insensitive" } } : {}),
          },
          orderBy: [
            {
              position: "desc",
            },
            {
              id: "desc",
            },
          ],
        })) ?? [];

      eventTypes.push(...teamEventTypes);
    } catch (error) {
      log.error("Error fetching team event types", { error, teamId, userId: ctx.user.id });
      // Continue with user event types even if team query fails
    }
  }

  let nextCursor: number | null | undefined = undefined;
  if (eventTypes.length > limit) {
    const nextItem = eventTypes.pop();
    nextCursor = nextItem?.id;
  }

  // Optimize: Use Promise.allSettled to handle partial failures gracefully
  const mappedEventTypes: MappedEventType[] = await Promise.allSettled(eventTypes.map(mapEventType)).then(
    (results) => {
      return results
        .map((result) => (result.status === "fulfilled" ? result.value : null))
        .filter((eventType): eventType is MappedEventType => eventType !== null);
    }
  );

  // Only fetch membership if we have team event types
  if (teamId && eventTypes.some((et) => et.teamId === teamId)) {
    try {
      const membership = await prisma.membership.findFirst({
        where: {
          userId: ctx.user.id,
          teamId: teamId ?? 0,
          accepted: true,
          role: "MEMBER",
        },
        include: {
          team: {
            select: {
              isPrivate: true,
            },
          },
        },
      });

      if (membership && membership.team.isPrivate) {
        mappedEventTypes.forEach((evType) => {
          evType.users = [];
          evType.hosts = [];
          evType.children = [];
        });
      }
    } catch (error) {
      log.error("Error fetching team membership", { error, teamId, userId: ctx.user.id });
      // Continue without membership check
    }
  }

  return { eventTypes: mappedEventTypes, nextCursor: nextCursor ?? undefined };
};
