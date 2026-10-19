"use client"

import { useEffect, useState } from "react"
import ReactMarkdown from "react-markdown"
import remarkGfm from "remark-gfm"
import { Sparkles, Send, Code2, PanelRightClose, PanelRightOpen } from "lucide-react"

type Turn = { role: "user" | "assistant"; text: string; sql?: string }

// Rehearsed demo questions: opener, drill-down, curveball.
const STARTERS = [
  "What is the current LCR and how does it trend over the next 30 days?",
  "Break down our HQLA by asset category. Which categories hold the most value?",
  "Compare the baseline forecast with the what-if stress scenario.",
  "On which day does the LCR first drop below 15x?",
]

// Staged status lines so a 60s agent run reads as progress, not a frozen app.
const STAGES = [
  "Reading the LIQUIDITY_SV semantic model…",
  "Planning the analysis…",
  "Generating governed SQL…",
  "Running the query in Snowflake…",
  "Summarizing results…",
]

function Progress() {
  const [secs, setSecs] = useState(0)
  useEffect(() => {
    const t = setInterval(() => setSecs((s) => s + 1), 1000)
    return () => clearInterval(t)
  }, [])
  const stage = STAGES[Math.min(Math.floor(secs / 8), STAGES.length - 1)]
  return (
    <div className="flex items-center gap-3 text-sm text-muted-foreground">
      <span className="relative flex h-2.5 w-2.5">
        <span className="absolute inline-flex h-full w-full rounded-full bg-[#29B5E8] opacity-75 animate-ping" />
        <span className="relative inline-flex h-2.5 w-2.5 rounded-full bg-[#29B5E8]" />
      </span>
      <span>{stage}</span>
      <span className="font-mono text-xs">{secs}s</span>
    </div>
  )
}

// Agent answers are markdown (tables, bullets, bold). Styled for a 420px pane:
// tables scroll horizontally, numeric cells right-align, rows are zebra-striped.
const isNumeric = (c: unknown) => typeof c === "string" && /^[\s$€£+\-−~(]*[\d.,]+[\s%xXBMKk)]*$/.test(c)
const cellText = (children: React.ReactNode): string =>
  Array.isArray(children) ? children.map(cellText).join("") : typeof children === "string" || typeof children === "number" ? String(children) : ""

const MD: React.ComponentProps<typeof ReactMarkdown>["components"] = {
  p: ({ children }) => <p className="mb-2 last:mb-0 leading-relaxed">{children}</p>,
  ul: ({ children }) => <ul className="list-disc pl-5 mb-2 space-y-1">{children}</ul>,
  ol: ({ children }) => <ol className="list-decimal pl-5 mb-2 space-y-1">{children}</ol>,
  strong: ({ children }) => <strong className="font-semibold">{children}</strong>,
  h1: ({ children }) => <p className="font-semibold mt-2 mb-1">{children}</p>,
  h2: ({ children }) => <p className="font-semibold mt-2 mb-1">{children}</p>,
  h3: ({ children }) => <p className="font-semibold mt-2 mb-1">{children}</p>,
  code: ({ children }) => <code className="px-1 py-0.5 rounded bg-background/70 font-mono text-xs">{children}</code>,
  table: ({ children }) => (
    <div className="my-2 -mx-1 overflow-x-auto rounded-md border border-border bg-background">
      <table className="w-full text-xs border-collapse">{children}</table>
    </div>
  ),
  thead: ({ children }) => <thead className="bg-[#29B5E8]/10">{children}</thead>,
  tr: ({ children }) => <tr className="border-b border-border/60 last:border-0 even:bg-muted/50">{children}</tr>,
  th: ({ children }) => <th className="px-2 py-1.5 text-left font-semibold whitespace-nowrap">{children}</th>,
  td: ({ children }) => (
    <td className={`px-2 py-1.5 whitespace-nowrap ${isNumeric(cellText(children)) ? "text-right font-mono tabular-nums" : ""}`}>{children}</td>
  ),
}

export function AgentPanel() {
  const [turns, setTurns] = useState<Turn[]>([])
  const [input, setInput] = useState("")
  const [busy, setBusy] = useState(false)
  const [suggestions, setSuggestions] = useState<string[]>(STARTERS)
  const [open, setOpen] = useState(true)

  async function ask(q: string) {
    if (!q.trim() || busy) return
    const next = [...turns, { role: "user" as const, text: q }]
    setTurns(next)
    setInput("")
    setBusy(true)
    try {
      const res = await fetch("/api/agent", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ messages: next.map(({ role, text }) => ({ role, text })) }),
      })
      const json = await res.json()
      if (!res.ok) throw new Error(json.error)
      setTurns([...next, { role: "assistant", text: json.answer, sql: json.sql }])
      if (json.suggestions?.length) setSuggestions(json.suggestions)
    } catch (e) {
      setTurns([...next, { role: "assistant", text: `Agent error: ${e instanceof Error ? e.message : e}` }])
    } finally {
      setBusy(false)
    }
  }

  if (!open) {
    return (
      <button onClick={() => setOpen(true)} title="Open Liquidity Agent"
        className="fixed right-4 bottom-4 z-40 inline-flex items-center gap-2 px-4 py-3 rounded-full bg-[#29B5E8] text-white shadow-lg">
        <PanelRightOpen size={16} /> Ask the Agent
      </button>
    )
  }

  return (
    <aside className="sticky top-0 h-screen w-[420px] shrink-0 flex flex-col bg-card border-l border-border">
      <header className="flex items-center gap-3 px-5 py-4 border-b border-border bg-gradient-to-r from-[#29B5E8]/15 to-transparent">
        <div className="p-2 rounded-lg bg-[#29B5E8] text-white"><Sparkles size={16} /></div>
        <div>
          <h2 className="font-semibold">Ask the Liquidity Agent</h2>
          <p className="text-xs text-muted-foreground">Cortex Agent over the LIQUIDITY_SV semantic view, governed by your Snowflake role</p>
        </div>
        <button onClick={() => setOpen(false)} title="Collapse" className="ml-auto p-1 rounded hover:bg-accent">
          <PanelRightClose size={16} />
        </button>
      </header>

      <div className="flex-1 px-5 py-4 space-y-4 overflow-y-auto">
        {turns.length === 0 && (
          <p className="text-sm text-muted-foreground">Ask about LCR, HQLA, cash flows or scenarios in plain English.</p>
        )}
        {turns.map((t, i) => (
          <div key={i} className={t.role === "user" ? "flex justify-end" : ""}>
            <div className={`max-w-[85%] rounded-lg px-4 py-3 text-sm ${
              t.role === "user" ? "bg-primary text-primary-foreground" : "bg-muted"}`}>
              {t.role === "user" ? t.text : <ReactMarkdown remarkPlugins={[remarkGfm]} components={MD}>{t.text}</ReactMarkdown>}
              {t.sql && (
                <details className="mt-2">
                  <summary className="cursor-pointer text-xs text-muted-foreground inline-flex items-center gap-1">
                    <Code2 size={12} /> Generated SQL
                  </summary>
                  <pre className="mt-2 text-xs bg-background/60 p-2 rounded overflow-x-auto">{t.sql}</pre>
                </details>
              )}
            </div>
          </div>
        ))}
        {busy && <Progress />}
      </div>

      <div className="px-5 pb-3 flex flex-wrap gap-2">
        {suggestions.slice(0, 4).map((s) => (
          <button key={s} onClick={() => ask(s)} disabled={busy}
            className="text-xs px-3 py-1.5 rounded-full border border-border hover:bg-accent disabled:opacity-50 text-left">
            {s}
          </button>
        ))}
      </div>

      <form onSubmit={(e) => { e.preventDefault(); ask(input) }} className="flex gap-2 px-5 pb-5">
        <input value={input} onChange={(e) => setInput(e.target.value)} placeholder="Ask a liquidity question…"
          className="flex-1 bg-background border border-border rounded-lg px-3 py-2 text-sm outline-none focus:ring-2 focus:ring-[#29B5E8]/50" />
        <button disabled={busy || !input.trim()}
          className="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium rounded-lg bg-[#29B5E8] text-white disabled:opacity-50">
          <Send size={14} /> Ask
        </button>
      </form>
    </aside>
  )
}
