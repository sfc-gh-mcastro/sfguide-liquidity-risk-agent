"use client"

import { useEffect, useState } from "react"
import { Database, Zap, ShieldCheck, ArrowDownRight, Gauge, Save, Check } from "lucide-react"
import type { WhatIfDefinition } from "@/app/what-if/page"

// Animated data flow shown while the what-if notebook runs. Steps advance on a
// timer (the notebook exposes no progress), hold on the last step if the run
// is slower, and all snap to done once the caller passes done=true.
const STEP_SECONDS = 7

type Node = { id: number; label: string; detail: string; icon: React.ReactNode }

const NODES: Node[] = [
  { id: 0, label: "RAW_SANDBOX", detail: "Zero-copy clone of positions & cash flows", icon: <Database size={16} /> },
  { id: 1, label: "Apply shocks", detail: "Scenario factors applied to sandbox rows", icon: <Zap size={16} /> },
  { id: 2, label: "HQLA", detail: "Re-value liquid assets after haircuts", icon: <ShieldCheck size={16} /> },
  { id: 2, label: "Net outflows", detail: "Re-project 30-day stressed outflows", icon: <ArrowDownRight size={16} /> },
  { id: 3, label: "LCR", detail: "HQLA ÷ net cash outflows, per day", icon: <Gauge size={16} /> },
  { id: 4, label: "WHAT_IF_LCR", detail: "Persist scenario results", icon: <Save size={16} /> },
]
const LAST = 4

function pct(factor: string) {
  const n = Number(factor)
  return Number.isFinite(n) ? `${n > 0 ? "+" : "−"}${Math.abs(n * 100).toFixed(0)}%` : factor
}

export function WhatIfFlow({ defs, done }: { defs: WhatIfDefinition[]; done: boolean }) {
  const [secs, setSecs] = useState(0)
  useEffect(() => {
    if (done) return
    const t = setInterval(() => setSecs((s) => s + 1), 1000)
    return () => clearInterval(t)
  }, [done])

  const active = done ? LAST + 1 : Math.min(Math.floor(secs / STEP_SECONDS), LAST)
  const state = (id: number) => (id < active ? "done" : id === active ? "active" : "idle")

  const box = (n: Node) => {
    const s = state(n.id)
    return (
      <div key={n.label} className={`flex-1 min-w-0 rounded-lg border px-3 py-2.5 transition-all duration-500 ${
        s === "active" ? "border-[#29B5E8] bg-[#29B5E8]/10 shadow-[0_0_0_3px_rgba(41,181,232,0.15)] animate-pulse"
        : s === "done" ? "border-emerald-500/50 bg-emerald-500/5" : "border-border opacity-50"}`}>
        <div className="flex items-center gap-2">
          <span className={`p-1 rounded ${s === "done" ? "bg-emerald-500 text-white" : s === "active" ? "bg-[#29B5E8] text-white" : "bg-muted text-muted-foreground"}`}>
            {s === "done" ? <Check size={14} /> : n.icon}
          </span>
          <span className="font-mono text-xs font-semibold truncate">{n.label}</span>
        </div>
        <p className="text-[11px] text-muted-foreground mt-1 leading-snug">{n.detail}</p>
      </div>
    )
  }

  const arrow = (id: number) => (
    <div className={`self-center text-lg transition-colors ${active > id ? "text-emerald-500" : active === id ? "text-[#29B5E8]" : "text-border"}`}>→</div>
  )

  return (
    <section className="mb-6 bg-card border border-border rounded-xl p-5">
      <div className="flex items-center justify-between mb-4">
        <div>
          <h2 className="font-semibold">{done ? "Scenario complete" : "Running scenario inside Snowflake"}</h2>
          <p className="text-xs text-muted-foreground">Notebook on governed sandbox data — nothing leaves the platform</p>
        </div>
        <span className="font-mono text-xs text-muted-foreground">{secs}s</span>
      </div>

      <div className="flex gap-2 items-stretch">
        {box(NODES[0])}
        {arrow(0)}
        {box(NODES[1])}
        {arrow(1)}
        <div className="flex-1 min-w-0 flex flex-col gap-2">{box(NODES[2])}{box(NODES[3])}</div>
        {arrow(2)}
        {box(NODES[4])}
        {arrow(3)}
        {box(NODES[5])}
      </div>

      {defs.length > 0 && (
        <div className={`mt-4 transition-opacity duration-500 ${active >= 1 ? "opacity-100" : "opacity-40"}`}>
          <p className="text-[11px] uppercase tracking-wide text-muted-foreground mb-1.5">Shocks applied</p>
          <div className="flex flex-wrap gap-1.5">
            {defs.map((d, i) => (
              <span key={i} className={`text-xs px-2 py-1 rounded-full border ${
                Number(d.factor) < 0 ? "border-red-500/40 bg-red-500/10 text-red-600 dark:text-red-400" : "border-emerald-500/40 bg-emerald-500/10"}`}
                title={`${d.refTbl}.${d.col} = ${d.val}`}>
                {d.val} <span className="font-mono">{pct(d.factor)}</span>
                <span className="text-muted-foreground"> · {d.refTbl.toLowerCase().replaceAll("_", " ")}</span>
              </span>
            ))}
          </div>
        </div>
      )}
    </section>
  )
}
