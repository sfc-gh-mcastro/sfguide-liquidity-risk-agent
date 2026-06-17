"use client"

import { useState, useCallback, useMemo } from "react"
import { Play, TrendingUp, DollarSign, ArrowDownRight } from "lucide-react"
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend,
  ResponsiveContainer, ReferenceLine,
} from "recharts"
import type { WhatIfDefinition } from "./page"

interface ResultPoint {
  dayNumber: number
  lcr: number
  hqla: number
  totalNetCashOutflows: number
}

interface Props {
  initialDefinitions: WhatIfDefinition[]
  initialError?: string
}

export function WhatIfScenarios({ initialDefinitions, initialError }: Props) {
  const [definitions] = useState(initialDefinitions)
  const [error, setError] = useState(initialError)
  const [selectedId, setSelectedId] = useState<string>("")
  const [executing, setExecuting] = useState(false)
  const [results, setResults] = useState<ResultPoint[]>([])

  const whatIfIds = useMemo(() => {
    const ids = [...new Set(definitions.map((d) => d.whatIfId))]
    return ids.sort()
  }, [definitions])

  const filteredDefs = useMemo(
    () => definitions.filter((d) => d.whatIfId === selectedId),
    [definitions, selectedId]
  )

  const execute = useCallback(async () => {
    if (!selectedId) return
    setExecuting(true)
    setError(undefined)
    setResults([])
    try {
      const execRes = await fetch("/api/what-if/execute", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ whatIfId: selectedId }),
      })
      const execJson = await execRes.json()
      if (execJson.error) {
        setError(execJson.error)
        return
      }

      const resultsRes = await fetch(`/api/what-if/results?whatIfId=${encodeURIComponent(selectedId)}`)
      const resultsJson = await resultsRes.json()
      if (resultsJson.error) {
        setError(resultsJson.error)
      } else {
        setResults(resultsJson.data)
      }
    } catch {
      setError("Network error executing scenario")
    } finally {
      setExecuting(false)
    }
  }, [selectedId])

  const day1 = results.find((r) => r.dayNumber === 1)

  return (
    <main className="w-full py-8 px-4 max-w-7xl mx-auto">
      <div className="mb-6">
        <h1 className="text-2xl font-bold">What-if Scenario Analysis</h1>
        <p className="text-sm text-muted-foreground">Run pre-defined scenarios to analyze impact on LCR</p>
      </div>

      {error && (
        <div className="bg-destructive/10 border border-destructive/30 rounded-lg p-4 mb-6 text-sm text-destructive">
          {error}
        </div>
      )}

      <div className="bg-card border border-border rounded-lg p-6 mb-6">
        <div className="flex items-end gap-4 flex-wrap">
          <div className="flex-1 min-w-[200px]">
            <label className="block text-sm font-medium mb-2">Select What-If Scenario</label>
            <select
              value={selectedId}
              onChange={(e) => { setSelectedId(e.target.value); setResults([]) }}
              className="w-full px-3 py-2 text-sm border border-border rounded-lg bg-background"
            >
              <option value="">Choose a scenario...</option>
              {whatIfIds.map((id) => (
                <option key={id} value={id}>{id}</option>
              ))}
            </select>
          </div>
          <button
            onClick={execute}
            disabled={!selectedId || executing}
            className="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium bg-primary text-primary-foreground rounded-lg hover:opacity-90 disabled:opacity-50"
          >
            <Play size={14} />
            {executing ? "Executing..." : "Execute Scenario"}
          </button>
        </div>
      </div>

      {selectedId && filteredDefs.length > 0 && (
        <details className="mb-6 bg-card border border-border rounded-lg">
          <summary className="px-4 py-3 text-sm font-medium cursor-pointer hover:bg-accent/50">
            View What-if Definition
          </summary>
          <div className="overflow-x-auto p-4 pt-0">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border">
                  <th className="text-left py-2 px-3 font-medium text-muted-foreground">What-If ID</th>
                  <th className="text-left py-2 px-3 font-medium text-muted-foreground">Name</th>
                  <th className="text-left py-2 px-3 font-medium text-muted-foreground">Ref Table</th>
                  <th className="text-left py-2 px-3 font-medium text-muted-foreground">Column</th>
                  <th className="text-left py-2 px-3 font-medium text-muted-foreground">Value</th>
                  <th className="text-right py-2 px-3 font-medium text-muted-foreground">Factor</th>
                </tr>
              </thead>
              <tbody>
                {filteredDefs.map((def, i) => (
                  <tr key={i} className="border-b border-border/50">
                    <td className="py-2 px-3 font-mono text-xs">{def.whatIfId}</td>
                    <td className="py-2 px-3">{def.whatIfName}</td>
                    <td className="py-2 px-3 font-mono text-xs">{def.refTbl}</td>
                    <td className="py-2 px-3 font-mono text-xs">{def.col}</td>
                    <td className="py-2 px-3">{def.val}</td>
                    <td className="py-2 px-3 text-right font-mono">{def.factor}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </details>
      )}

      {results.length > 0 && (
        <>
          {day1 && (
            <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-6">
              <MetricCard
                icon={<TrendingUp size={20} />}
                label="LCR"
                value={day1.lcr.toFixed(4)}
                status={day1.lcr >= 1.0 ? "Compliant" : "Non-Compliant"}
                statusColor={day1.lcr >= 1.0 ? "text-green-600" : "text-red-600"}
              />
              <MetricCard
                icon={<DollarSign size={20} />}
                label="HQLA"
                value={`$${day1.hqla.toLocaleString(undefined, { maximumFractionDigits: 2 })}`}
              />
              <MetricCard
                icon={<ArrowDownRight size={20} />}
                label="Total Net Cash Outflows (30d)"
                value={`$${day1.totalNetCashOutflows.toLocaleString(undefined, { maximumFractionDigits: 2 })}`}
              />
            </div>
          )}

          <div className="bg-card border border-border rounded-lg p-6 mb-6">
            <h2 className="text-lg font-semibold mb-1">What-if Scenario: {selectedId}</h2>
            <p className="text-sm text-muted-foreground mb-4">LCR forecast under scenario conditions</p>
            <ResponsiveContainer width="100%" height={400}>
              <LineChart data={results} margin={{ top: 8, right: 16, left: 0, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" className="stroke-border" />
                <XAxis
                  dataKey="dayNumber"
                  tick={{ fontSize: 12 }}
                  label={{ value: "Day Number", position: "insideBottom", offset: -4, fontSize: 12 }}
                />
                <YAxis tick={{ fontSize: 12 }} />
                <Tooltip
                  contentStyle={{ fontSize: 12, borderRadius: 8, border: "1px solid var(--border)" }}
                  formatter={(v: number) => [v.toFixed(4), "LCR"]}
                />
                <Legend wrapperStyle={{ fontSize: 12 }} />
                <ReferenceLine y={1.0} stroke="#ef4444" strokeDasharray="5 5" label={{ value: "Min Compliance (1.0)", fill: "#ef4444", fontSize: 11 }} />
                <Line type="monotone" dataKey="lcr" stroke="var(--brand-primary)" strokeWidth={2} dot={{ r: 3 }} name="LCR (What-if)" />
              </LineChart>
            </ResponsiveContainer>
          </div>

          <details className="bg-card border border-border rounded-lg">
            <summary className="px-4 py-3 text-sm font-medium cursor-pointer hover:bg-accent/50">
              View What-if Results Data
            </summary>
            <div className="overflow-x-auto p-4 pt-0">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border">
                    <th className="text-left py-2 px-3 font-medium text-muted-foreground">Day</th>
                    <th className="text-right py-2 px-3 font-medium text-muted-foreground">LCR</th>
                    <th className="text-right py-2 px-3 font-medium text-muted-foreground">HQLA</th>
                    <th className="text-right py-2 px-3 font-medium text-muted-foreground">Net Cash Outflows</th>
                  </tr>
                </thead>
                <tbody>
                  {results.map((row) => (
                    <tr key={row.dayNumber} className="border-b border-border/50">
                      <td className="py-2 px-3">{row.dayNumber}</td>
                      <td className="py-2 px-3 text-right font-mono">{row.lcr.toFixed(4)}</td>
                      <td className="py-2 px-3 text-right font-mono">${row.hqla.toLocaleString(undefined, { maximumFractionDigits: 0 })}</td>
                      <td className="py-2 px-3 text-right font-mono">${row.totalNetCashOutflows.toLocaleString(undefined, { maximumFractionDigits: 0 })}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </details>
        </>
      )}
    </main>
  )
}

function MetricCard({ icon, label, value, status, statusColor }: {
  icon: React.ReactNode
  label: string
  value: string
  status?: string
  statusColor?: string
}) {
  return (
    <div className="bg-card border border-border rounded-lg p-5 flex items-start gap-4">
      <div className="p-2 bg-primary/10 text-primary rounded-lg shrink-0">{icon}</div>
      <div>
        <p className="text-sm text-muted-foreground">{label}</p>
        <p className="text-2xl font-bold mt-1">{value}</p>
        {status && <p className={`text-xs mt-1 font-medium ${statusColor}`}>{status}</p>}
      </div>
    </div>
  )
}
