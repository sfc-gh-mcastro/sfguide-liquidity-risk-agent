import type { Metadata } from "next"
import type React from "react"
import { AppHeader } from "@/components/app-header"
import { AgentPanel } from "@/components/agent-panel"
import { ThemeProvider } from "@/components/theme-provider"
import { APP_TITLE, LOGO_SRC } from "@/lib/constants"
import "./globals.css"

export const metadata: Metadata = {
  title: APP_TITLE,
  description: "LCR metrics, what-if scenario analysis, and liquidity risk monitoring",
  icons: { icon: LOGO_SRC },
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body className="antialiased">
        <ThemeProvider>
          <AppHeader />
          <div className="flex">
            <div className="flex-1 min-w-0">{children}</div>
            <AgentPanel />
          </div>
        </ThemeProvider>
      </body>
    </html>
  )
}
