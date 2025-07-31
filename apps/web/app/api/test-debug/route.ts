import { NextResponse } from "next/server";

export async function GET() {
  console.log("=== Test Debug Endpoint Called ===");
  return NextResponse.json({ message: "Test endpoint working" });
}

export async function POST() {
  console.log("=== Test Debug POST Called ===");
  return NextResponse.json({ message: "Test POST working" });
}
