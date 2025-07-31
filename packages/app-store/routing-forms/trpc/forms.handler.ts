import { hasFilter } from "@calcom/features/filters/lib/hasFilter";
import { entityPrismaWhereClause } from "@calcom/lib/entityPermissionUtils.server";
import logger from "@calcom/lib/logger";
import type { PrismaClient } from "@calcom/prisma";
import type { Prisma } from "@calcom/prisma/client";
import { entries } from "@calcom/prisma/zod-utils";
import type { TrpcSessionUser } from "@calcom/trpc/server/types";

import type { TFormSchema } from "./forms.schema";

interface FormsHandlerOptions {
  ctx: {
    prisma: PrismaClient;
    user: NonNullable<TrpcSessionUser>;
  };
  input: TFormSchema;
}
const log = logger.getSubLogger({ prefix: ["[formsHandler]"] });

export const formsHandler = async ({ ctx, input }: FormsHandlerOptions) => {
  const { prisma, user } = ctx;

  try {
    const where = getPrismaWhereFromFilters(user, input?.filters);
    log.debug("Getting forms where", JSON.stringify(where));

    // Optimize: Use a single query with better conditions
    const forms = await prisma.app_RoutingForms_Form.findMany({
      where,
      orderBy: [
        {
          position: "desc",
        },
        {
          createdAt: "desc",
        },
      ],
      include: {
        team: {
          select: {
            id: true,
            name: true,
            members: {
              select: {
                userId: true,
                role: true,
              },
            },
          },
        },
        _count: {
          select: {
            responses: true,
          },
        },
      },
    });

    const totalForms = await prisma.app_RoutingForms_Form.count({
      where: entityPrismaWhereClause({
        userId: user.id,
      }),
    });

    return {
      filtered: await buildFormsWithReadOnlyStatus(),
      totalCount: totalForms,
    };

    async function buildFormsWithReadOnlyStatus() {
      return forms.map((form) => {
        const readOnly = !!form.team?.members?.find(
          (member) => member.userId === user.id && member.role === "MEMBER"
        );

        return {
          form,
          readOnly,
          hasError: false,
        };
      });
    }
  } catch (error) {
    log.error("Error fetching forms", { userId: user.id, error });
    return {
      filtered: [],
      totalCount: 0,
    };
  }
};

export default formsHandler;
type SupportedFilters = Omit<NonNullable<NonNullable<TFormSchema>["filters"]>, "upIds"> | undefined;

export function getPrismaWhereFromFilters(
  user: {
    id: number;
  },
  filters: SupportedFilters
) {
  const where = {
    OR: [] as Prisma.App_RoutingForms_FormWhereInput[],
  };

  const prismaQueries: Record<
    keyof NonNullable<typeof filters>,
    (...args: [number[]]) => Prisma.App_RoutingForms_FormWhereInput
  > & {
    all: () => Prisma.App_RoutingForms_FormWhereInput;
  } = {
    userIds: (userIds: number[]) => ({
      userId: {
        in: userIds,
      },
      teamId: null,
    }),
    teamIds: (teamIds: number[]) => ({
      team: {
        id: {
          in: teamIds ?? [],
        },
        members: {
          some: {
            userId: user.id,
            accepted: true,
          },
        },
      },
    }),
    all: () => ({
      OR: [
        {
          userId: user.id,
        },
        {
          team: {
            members: {
              some: {
                userId: user.id,
                accepted: true,
              },
            },
          },
        },
      ],
    }),
  };

  if (!filters || !hasFilter(filters)) {
    where.OR.push(prismaQueries.all());
  } else {
    for (const entry of entries(filters)) {
      if (!entry) {
        continue;
      }
      const [filterName, filter] = entry;
      const getPrismaQuery = prismaQueries[filterName];
      // filter might be accidentally set undefined as well
      if (!getPrismaQuery || !filter) {
        continue;
      }
      where.OR.push(getPrismaQuery(filter));
    }
  }

  return where;
}
