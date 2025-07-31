import * as z from "zod"
import * as imports from "../zod-utils"
import { WebhookTriggerEvents, TimeUnit } from "@prisma/client"
import { CompleteApp, AppModel, CompleteEventType, EventTypeModel, CompletePlatformOAuthClient, PlatformOAuthClientModel, CompleteTeam, TeamModel, CompleteUser, UserModel, CompleteWebhookScheduledTriggers, WebhookScheduledTriggersModel } from "./index"

export const _WebhookModel = z.object({
  id: z.string(),
  userId: z.number().int().nullish(),
  subscriberUrl: z.string().url(),
  createdAt: z.date(),
  active: z.boolean(),
  eventTriggers: z.nativeEnum(WebhookTriggerEvents).array(),
  payloadTemplate: z.string().nullish(),
  eventTypeId: z.number().int().nullish(),
  appId: z.string().nullish(),
  secret: z.string().nullish(),
  teamId: z.number().int().nullish(),
  platform: z.boolean(),
  platformOAuthClientId: z.string().nullish(),
  time: z.number().int().nullish(),
  timeUnit: z.nativeEnum(TimeUnit).nullish(),
})

export interface CompleteWebhook extends z.infer<typeof _WebhookModel> {
  app?: CompleteApp | null
  eventType?: CompleteEventType | null
  platformOAuthClient?: CompletePlatformOAuthClient | null
  team?: CompleteTeam | null
  user?: CompleteUser | null
  scheduledTriggers: CompleteWebhookScheduledTriggers[]
}

/**
 * WebhookModel contains all relations on your model in addition to the scalars
 *
 * NOTE: Lazy required in case of potential circular dependencies within schema
 */
export const WebhookModel: z.ZodSchema<CompleteWebhook> = z.lazy(() => _WebhookModel.extend({
  app: AppModel.nullish(),
  eventType: EventTypeModel.nullish(),
  platformOAuthClient: PlatformOAuthClientModel.nullish(),
  team: TeamModel.nullish(),
  user: UserModel.nullish(),
  scheduledTriggers: WebhookScheduledTriggersModel.array(),
}))
