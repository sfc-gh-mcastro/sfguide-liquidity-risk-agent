import { querySnowflake } from "@/lib/snowflake"
import { DB } from "@/lib/constants"
import { LcrDashboard } from "./lcr-dashboard"

export const dynamic = "force-dynamic"

export interface LcrPoint {
  dayNumber: number
  lcr: number
  hqla: number
  totalNetCashOutflows: number
}

export default async function Page() {
  let lcrData: LcrPoint[] = []
  let error: string | undefined

  try {
    const rows = await querySnowflake(`
      SELECT DAY_NUMBER, LCR, HQLA, TOTAL_NET_CASH_OUTFLOWS
      FROM ${DB}.PRESENTATION.LCR
      WHERE created_timestamp IN (SELECT MAX(created_timestamp) FROM ${DB}.PRESENTATION.LCR)
      ORDER BY DAY_NUMBER
    `)

    lcrData = (rows as Record<string, unknown>[]).map((r) => ({
      dayNumber: Number(r["DAY_NUMBER"]),
      lcr: Number(r["LCR"]),
      hqla: Number(r["HQLA"]),
      totalNetCashOutflows: Number(r["TOTAL_NET_CASH_OUTFLOWS"]),
    }))
  } catch (e) {
    error = e instanceof Error ? e.message : "Failed to load LCR data"
  }

  return <LcrDashboard initialData={lcrData} initialError={error} />
}
