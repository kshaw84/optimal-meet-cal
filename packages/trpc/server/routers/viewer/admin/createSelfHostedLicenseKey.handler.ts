import * as crypto from "crypto";
import { z } from "zod";

// CALCOM_PRIVATE_API_ROUTE removed for self-hosted deployments
import type { TrpcSessionUser } from "../../../types";
import type { TCreateSelfHostedLicenseSchema } from "./createSelfHostedLicenseKey.schema";

type GetOptions = {
  ctx: {
    user: NonNullable<TrpcSessionUser>;
  };
  input: TCreateSelfHostedLicenseSchema;
};

const generateNonce = (): string => {
  return crypto.randomBytes(16).toString("hex");
};

// Utility function to create a signature
const createSignature = (body: Record<string, unknown>, nonce: string, secretKey: string): string => {
  return crypto
    .createHmac("sha256", secretKey)
    .update(JSON.stringify(body) + nonce)
    .digest("hex");
};

// Fetch wrapper function
const fetchWithSignature = async (
  url: string,
  body: Record<string, unknown>,
  secretKey: string,
  options: RequestInit = {}
): Promise<Response> => {
  const nonce = generateNonce();
  const signature = createSignature(body, nonce, secretKey);

  const headers = {
    ...options.headers,
    "Content-Type": "application/json",
    nonce: nonce,
    signature: signature,
  };

  return await fetch(url, {
    ...options,
    method: "POST",
    headers: headers,
    body: JSON.stringify(body),
  });
};

const createSelfHostedInstance = async ({ input, ctx }: GetOptions) => {
  const privateApiUrl = "https://goblin.cal.com"; // Fallback for self-hosted
  const signatureToken = process.env.CAL_SIGNATURE_TOKEN;

  if (!signatureToken) {
    throw new Error("CAL_SIGNATURE_TOKEN does not exist in .env");
  }

  // Ensure admin
  if (ctx.user.role !== "ADMIN") {
    console.warn(`${ctx.user.username} just tried to create a license key without permission`);
    throw new Error("You do not have permission to do this.");
  }

  const request = await fetchWithSignature(`${privateApiUrl}/v1/license`, input, signatureToken, {
    method: "POST",
  });

  const data = await request.json();
  const schema = z.object({
    stripeCheckoutUrl: z.string(),
  });

  return schema.parse(data);
};

export default createSelfHostedInstance;
