import { querySnowflake } from "@/lib/snowflake"
import { DB } from "@/lib/constants"

export const dynamic = "force-dynamic"

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url)
  const whatIfId = searchParams.get("whatIfId")

  if (!whatIfId) {
    return Response.json({ error: "whatIfId query param is required" }, { status: 400 })
  }

  try {
    const rows = await querySnowflake(`
      SELECT DAY_NUMBER, LCR, HQLA, TOTAL_NET_CASH_OUTFLOWS, WHAT_IF_ID
      FROM ${DB}.PRESENTATION.WHAT_IF_LCR
      WHERE what_if_id = '${whatIfId}'
        AND created_timestamp IN (
          SELECT MAX(created_timestamp)
          FROM ${DB}.PRESENTATION.WHAT_IF_LCR
          WHERE what_if_id = '${whatIfId}'
        )
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
    console.error(new Date().toISOString(), "[what-if/results] fetch failed", e)
    return Response.json(
      { error: e instanceof Error ? e.message : "Failed to load what-if results" },
      { status: 500 }
    )
  }
}
