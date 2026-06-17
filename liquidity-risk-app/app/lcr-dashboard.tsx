"use client"

import { useState, useCallback } from "react"
import { RefreshCw, TrendingUp, DollarSign, ArrowDownRight } from "lucide-react"
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend,
  ResponsiveContainer, ReferenceLine,
} from "recharts"
import type { LcrPoint } from "./page"

interface Props {
  initialData: LcrPoint[]
  initialError?: string
}

export function LcrDashboard({ initialData, initialError }: Props) {
  const [data, setData] = useState(initialData)
  const [error, setError] = useState(initialError)
  const [refreshing, setRefreshing] = useState(false)
  const [recalculating, setRecalculating] = useState(false)

  const refresh = useCallback(async () => {
    setRefreshing(true)
    setError(undefined)
    try {
      const res = await fetch("/api/lcr")
      const json = await res.json()
      if (json.error) setError(json.error)
      else setData(json.data)
    } catch {
      setError("Network error refreshing data")
    } finally {
      setRefreshing(false)
    }
  }, [])

  const recalculate = useCallback(async () => {
    setRecalculating(true)
    setError(undefined)
    try {
      const res = await fetch("/api/lcr/recalculate", { method: "POST" })
      const json = await res.json()
      if (json.error) {
        setError(json.error)
      } else {
        await refresh()
      }
    } catch {
      setError("Network error during recalculation")
    } finally {
      setRecalculating(false)
    }
  }, [refresh])

  const today = data.find((d) => d.dayNumber === 1)

  return (
    <main className="w-full py-8 px-4 max-w-7xl mx-auto">
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-2xl font-bold">Liquidity Coverage Ratio Dashboard</h1>
          <p className="text-sm text-muted-foreground">Real-time LCR metrics and trends</p>
        </div>
        <div className="flex gap-2">
          <button
            onClick={refresh}
            disabled={refreshing}
            className="inline-flex items-center gap-2 px-3 py-2 text-sm border border-border rounded-lg hover:bg-accent disabled:opacity-50"
          >
            <RefreshCw size={14} className={refreshing ? "animate-spin" : ""} />
            {refreshing ? "Refreshing..." : "Refresh"}
          </button>
          <button
            onClick={recalculate}
            disabled={recalculating}
            className="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium bg-primary text-primary-foreground rounded-lg hover:opacity-90 disabled:opacity-50"
          >
            {recalculating ? "Calculating..." : "Re-Calculate LCR"}
          </button>
        </div>
      </div>

      {error && (
        <div className="bg-destructive/10 border border-destructive/30 rounded-lg p-4 mb-6 text-sm text-destructive">
          {error}
        </div>
      )}

      {today && (
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
          <MetricCard
            icon={<TrendingUp size={20} />}
            label="LCR"
            value={today.lcr.toFixed(2)}
            status={today.lcr >= 1.0 ? "Compliant" : "Non-Compliant"}
            statusColor={today.lcr >= 1.0 ? "text-green-600" : "text-red-600"}
          />
          <MetricCard
            icon={<DollarSign size={20} />}
            label="HQLA"
            value={`$${today.hqla.toLocaleString(undefined, { maximumFractionDigits: 0 })}`}
          />
          <MetricCard
            icon={<ArrowDownRight size={20} />}
            label="Total Net Cash Outflows (30d)"
            value={`$${today.totalNetCashOutflows.toLocaleString(undefined, { maximumFractionDigits: 0 })}`}
          />
        </div>
      )}

      <div className="bg-card border border-border rounded-lg p-6">
        <h2 className="text-lg font-semibold mb-1">LCR Trend Over Time</h2>
        <p className="text-sm text-muted-foreground mb-4">Liquidity Coverage Ratio by forecast day</p>
        {data.length > 0 ? (
          <ResponsiveContainer width="100%" height={400}>
            <LineChart data={data} margin={{ top: 8, right: 16, left: 0, bottom: 0 }}>
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
              <Line type="monotone" dataKey="lcr" stroke="var(--brand-primary)" strokeWidth={2} dot={{ r: 3 }} name="LCR" />
            </LineChart>
          </ResponsiveContainer>
        ) : (
          <p className="text-center text-muted-foreground py-12">No LCR data available.</p>
        )}
      </div>

      {data.length > 0 && (
        <details className="mt-4 bg-card border border-border rounded-lg">
          <summary className="px-4 py-3 text-sm font-medium cursor-pointer hover:bg-accent/50">
            View Raw Data
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
                {data.map((row) => (
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
