import { querySnowflakeLongRunning } from "@/lib/snowflake"
import { DB } from "@/lib/constants"

export const dynamic = "force-dynamic"

export async function POST(request: Request) {
  try {
    const body = await request.json()
    const { whatIfId } = body

    if (!whatIfId) {
      return Response.json({ error: "whatIfId is required" }, { status: 400 })
    }

    const suffix = Math.random().toString(36).substring(2, 10)

    const notebookCall = `EXECUTE NOTEBOOK ${DB}.PUBLIC.LIQUIDITY_WHAT_IF_FORECAST_SANDBOX('db=${DB}', 'positions_table=${DB}.RAW_SANDBOX.POSITIONS', 'inflows_table=${DB}.RAW_SANDBOX.CASH_INFLOWS', 'outflows_table=${DB}.RAW_SANDBOX.CASH_OUTFLOWS', 'suffix=${suffix}', 'what_if_id=${whatIfId}')`

    await querySnowflakeLongRunning(notebookCall)

    return Response.json({ success: true, whatIfId })
  } catch (e) {
    console.error(new Date().toISOString(), "[what-if/execute] failed", e)
    return Response.json(
      { error: e instanceof Error ? e.message : "Failed to execute what-if scenario" },
      { status: 500 }
    )
  }
}
