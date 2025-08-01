import type { NextApiRequest, NextApiResponse } from "next";

export default function handler(req: NextApiRequest, res: NextApiResponse) {
  const { licenseKey } = req.query;

  // For self-hosted instances, always return valid license
  // This allows the license validation to work without external API calls
  res.status(200).json({
    status: true,
    message: "License valid for self-hosted instance",
    licenseKey: licenseKey,
  });
}
