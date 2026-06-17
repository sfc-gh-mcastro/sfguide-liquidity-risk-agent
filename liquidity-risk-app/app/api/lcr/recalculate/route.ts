import { querySnowflakeLongRunning } from "@/lib/snowflake"
import { DB } from "@/lib/constants"

export const dynamic = "force-dynamic"

export async function POST() {
  try {
    const notebookCall = `EXECUTE NOTEBOOK ${DB}.PUBLIC.LIQUIDITY_FORECAST('db=${DB}', 'positions_table=${DB}.raw.POSITIONS', 'inflows_table=${DB}.raw.CASH_INFLOWS', 'outflows_table=${DB}.raw.CASH_OUTFLOWS')`

    await querySnowflakeLongRunning(notebookCall)

    return Response.json({ success: true })
  } catch (e) {
    console.error(new Date().toISOString(), "[lcr/recalculate] failed", e)
    return Response.json(
      { error: e instanceof Error ? e.message : "Failed to execute LCR recalculation" },
      { status: 500 }
    )
  }
}
