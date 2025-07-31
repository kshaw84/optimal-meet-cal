import { createNextApiHandler } from "@calcom/trpc/server/createNextApiHandler";
import { viewerRouter } from "@calcom/trpc/server/routers/viewer/_router";

export default createNextApiHandler(viewerRouter);
