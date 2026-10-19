import { querySnowflakeLongRunning } from "@/lib/snowflake"
import { DB } from "@/lib/constants"

export const dynamic = "force-dynamic"

const AGENT = `${DB}.PUBLIC.LIQUIDITY_FORECAST_AGENT`

type Msg = { role: "user" | "assistant"; text: string }

// Calls the Cortex Agent through SQL (DATA_AGENT_RUN) so it reuses the app's
// existing Snowflake connection and role, then flattens the content blocks
// into answer text, generated SQL and follow-up suggestions for the UI.
export async function POST(req: Request) {
  try {
    const { messages } = (await req.json()) as { messages: Msg[] }
    if (!Array.isArray(messages) || messages.length === 0) {
      return Response.json({ error: "messages required" }, { status: 400 })
    }
    const body = JSON.stringify({
      stream: false,
      messages: messages.slice(-10).map((m) => ({
        role: m.role,
        content: [{ type: "text", text: String(m.text).slice(0, 4000) }],
      })),
    })
    // Bind via a dollar-quoted literal; strip any "$$" so input cannot escape it.
    const safe = body.replaceAll("$$", "")
    const rows = await querySnowflakeLongRunning(
      `SELECT TRY_PARSE_JSON(SNOWFLAKE.CORTEX.DATA_AGENT_RUN('${AGENT}', $$${safe}$$)):content::string AS C`
    )
    const blocks = JSON.parse(String(rows[0]?.C ?? "[]")) as any[]
    const texts: string[] = []
    let sql: string | undefined
    let suggestions: string[] = []
    for (const b of blocks) {
      if (b.type === "text" && b.text) texts.push(b.text)
      if (b.type === "tool_use" && b.tool_use?.name === "system_execute_sql") sql = b.tool_use.input?.sql
      if (b.type === "suggested_queries") suggestions = (b.suggested_queries ?? []).map((q: any) => q.query)
    }
    // The last text block is the final answer; earlier ones are planning notes.
    return Response.json({ answer: texts.at(-1) ?? "No answer returned.", sql, suggestions })
  } catch (e) {
    console.error(new Date().toISOString(), "[agent] run failed", e)
    return Response.json({ error: e instanceof Error ? e.message : "Agent call failed" }, { status: 500 })
  }
}
