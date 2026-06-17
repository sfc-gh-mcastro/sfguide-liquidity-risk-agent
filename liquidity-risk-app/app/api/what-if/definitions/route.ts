import { querySnowflake } from "@/lib/snowflake"
import { DB } from "@/lib/constants"

export const dynamic = "force-dynamic"

export async function GET() {
  try {
    const rows = await querySnowflake(`
      SELECT WHAT_IF_ID, WHAT_IF_NAME, REF_TBL, COL, VAL, FACTOR
      FROM ${DB}.RAW.WHAT_IF_DEFINITIONS_LOOKUP
      ORDER BY WHAT_IF_ID, REF_TBL, COL
    `)

    return Response.json({ data: rows })
  } catch (e) {
    console.error(new Date().toISOString(), "[what-if/definitions] fetch failed", e)
    return Response.json(
      { error: e instanceof Error ? e.message : "Failed to load what-if definitions" },
      { status: 500 }
    )
  }
}
