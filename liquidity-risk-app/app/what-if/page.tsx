import { querySnowflake } from "@/lib/snowflake"
import { DB } from "@/lib/constants"
import { WhatIfScenarios } from "./what-if-scenarios"

export const dynamic = "force-dynamic"

export interface WhatIfDefinition {
  whatIfId: string
  whatIfName: string
  refTbl: string
  col: string
  val: string
  factor: string
}

export default async function WhatIfPage() {
  let definitions: WhatIfDefinition[] = []
  let error: string | undefined

  try {
    const rows = await querySnowflake(`
      SELECT DISTINCT WHAT_IF_ID, WHAT_IF_NAME, REF_TBL, COL, VAL, FACTOR
      FROM ${DB}.RAW.WHAT_IF_DEFINITIONS_LOOKUP
      ORDER BY WHAT_IF_ID, REF_TBL, COL
    `)

    definitions = (rows as Record<string, unknown>[]).map((r) => ({
      whatIfId: String(r["WHAT_IF_ID"] ?? ""),
      whatIfName: String(r["WHAT_IF_NAME"] ?? ""),
      refTbl: String(r["REF_TBL"] ?? ""),
      col: String(r["COL"] ?? ""),
      val: String(r["VAL"] ?? ""),
      factor: String(r["FACTOR"] ?? ""),
    }))
  } catch (e) {
    error = e instanceof Error ? e.message : "Failed to load what-if definitions"
  }

  return <WhatIfScenarios initialDefinitions={definitions} initialError={error} />
}
