import { defaultResponderForAppDir } from "app/api/defaultResponderForAppDir";
import { parseRequestData } from "app/api/parseRequestData";
import crypto from "crypto";
import { cookies, headers } from "next/headers";
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { authenticator } from "otplib";
import qrcode from "qrcode";

import { ErrorCode } from "@calcom/features/auth/lib/ErrorCode";
import { getServerSession } from "@calcom/features/auth/lib/getServerSession";
import { verifyPassword } from "@calcom/features/auth/lib/verifyPassword";
import { symmetricEncrypt } from "@calcom/lib/crypto";
import prisma from "@calcom/prisma";
import { IdentityProvider } from "@calcom/prisma/enums";

import { buildLegacyRequest } from "@lib/buildLegacyCtx";

async function postHandler(req: NextRequest) {
  console.log("=== 2FA Setup Route Called ===");

  try {
    console.log("=== 2FA Setup Debug ===");

    const body = await parseRequestData(req);
    console.log("Request body parsed:", { hasPassword: !!body.password });

    const session = await getServerSession({ req: buildLegacyRequest(await headers(), await cookies()) });
    console.log("Session retrieved:", { hasSession: !!session, userId: session?.user?.id });

    if (!session) {
      return NextResponse.json({ message: "Not authenticated" }, { status: 401 });
    }

    if (!session.user?.id) {
      console.error("Session is missing a user id.");
      return NextResponse.json({ error: ErrorCode.InternalServerError }, { status: 500 });
    }

    console.log("Fetching user from database...");
    const user = await prisma.user.findUnique({
      where: { id: session.user.id },
      include: { password: true },
    });
    console.log("User fetched:", {
      hasUser: !!user,
      identityProvider: user?.identityProvider,
      hasPassword: !!user?.password?.hash,
      twoFactorEnabled: user?.twoFactorEnabled,
    });

    if (!user) {
      console.error(`Session references user that no longer exists.`);
      return NextResponse.json({ message: "Not authenticated" }, { status: 401 });
    }

    if (user.identityProvider !== IdentityProvider.CAL && !user.password?.hash) {
      return NextResponse.json({ error: ErrorCode.ThirdPartyIdentityProviderEnabled }, { status: 400 });
    }

    if (!user.password?.hash) {
      return NextResponse.json({ error: ErrorCode.UserMissingPassword }, { status: 400 });
    }

    if (user.twoFactorEnabled) {
      return NextResponse.json({ error: ErrorCode.TwoFactorAlreadyEnabled }, { status: 400 });
    }

    console.log("Checking encryption key...");
    if (!process.env.CALENDSO_ENCRYPTION_KEY) {
      console.error("Missing encryption key; cannot proceed with two factor setup.");
      return NextResponse.json({ error: ErrorCode.InternalServerError }, { status: 500 });
    }
    console.log("Encryption key found");
    console.log("Raw key:", process.env.CALENDSO_ENCRYPTION_KEY);
    console.log("Key length:", process.env.CALENDSO_ENCRYPTION_KEY.length);
    console.log("Key as latin1 length:", Buffer.from(process.env.CALENDSO_ENCRYPTION_KEY, "latin1").length);
    console.log("Key as latin1 bytes:", Buffer.from(process.env.CALENDSO_ENCRYPTION_KEY, "latin1"));

    console.log("Verifying password...");
    const isCorrectPassword = await verifyPassword(body.password, user.password.hash);
    console.log("Password verification result:", isCorrectPassword);

    if (!isCorrectPassword) {
      return NextResponse.json({ error: ErrorCode.IncorrectPassword }, { status: 400 });
    }

    console.log("Generating secret...");
    // This generates a secret 32 characters in length. Do not modify the number of
    // bytes without updating the sanity checks in the enable and login endpoints.
    const secret = authenticator.generateSecret(20);
    console.log("Secret generated");

    console.log("Generating backup codes...");
    // Generate backup codes with 10 character length
    const backupCodes = Array.from(Array(10), () => crypto.randomBytes(5).toString("hex"));
    console.log("Backup codes generated");

    console.log("Updating user in database...");
    await prisma.user.update({
      where: {
        id: session.user.id,
      },
      data: {
        backupCodes: symmetricEncrypt(JSON.stringify(backupCodes), process.env.CALENDSO_ENCRYPTION_KEY),
        twoFactorEnabled: false,
        twoFactorSecret: symmetricEncrypt(secret, process.env.CALENDSO_ENCRYPTION_KEY),
      },
    });
    console.log("User updated successfully");

    console.log("Generating QR code...");
    const name = user.email || user.username || user.id.toString();
    const keyUri = authenticator.keyuri(name, "Cal", secret);
    const dataUri = await qrcode.toDataURL(keyUri);
    console.log("QR code generated successfully");

    console.log("=== 2FA Setup Complete ===");
    return NextResponse.json({ secret, keyUri, dataUri, backupCodes });
  } catch (error) {
    console.error("=== 2FA Setup Error ===", error);
    // Return a more specific error message to help debug
    return NextResponse.json(
      {
        error: ErrorCode.InternalServerError,
        message: error instanceof Error ? error.message : "Unknown error",
        stack: error instanceof Error ? error.stack : undefined,
      },
      { status: 500 }
    );
  }
}

export const POST = defaultResponderForAppDir(postHandler);
