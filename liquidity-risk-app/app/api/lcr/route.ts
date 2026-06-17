import { querySnowflake } from "@/lib/snowflake"
import { DB } from "@/lib/constants"

export const dynamic = "force-dynamic"

export async function GET() {
  try {
    const rows = await querySnowflake(`
      SELECT DAY_NUMBER, LCR, HQLA, TOTAL_NET_CASH_OUTFLOWS
      FROM ${DB}.PRESENTATION.LCR
      WHERE created_timestamp IN (SELECT MAX(created_timestamp) FROM ${DB}.PRESENTATION.LCR)
      ORDER BY DAY_NUMBER
    `)

    const data = (rows as Record<string, unknown>[]).map((r) => ({
      dayNumber: Number(r["DAY_NUMBER"]),
      lcr: Number(r["LCR"]),
      hqla: Number(r["HQLA"]),
      totalNetCashOutflows: Number(r["TOTAL_NET_CASH_OUTFLOWS"]),
    }))

    return Response.json({ data })
  } catch (e) {
    console.error(new Date().toISOString(), "[lcr] fetch failed", e)
    return Response.json(
      { error: e instanceof Error ? e.message : "Failed to load LCR data" },
      { status: 500 }
    )
  }
}
