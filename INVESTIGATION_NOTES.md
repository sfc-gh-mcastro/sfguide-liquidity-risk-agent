# Liquidity Risk Agent - Investigation Notes

## Repository Overview

This is a **Snowflake QuickStart Guide** demonstrating how to build a **Liquidity Coverage Ratio (LCR)** analysis solution for Basel III banking regulatory compliance.

### Purpose

Build a complete liquidity risk management solution with:
- **Real-time LCR Dashboard** - Visualize liquidity metrics
- **What-If Scenario Analysis** - Run stress tests
- **AI-Powered Agent** - Natural language queries via Cortex Analyst

### Structure

```
├── scripts/
│   ├── setup.sql          # Full environment setup (13 sections)
│   └── teardown.sql       # Cleanup script
├── notebooks/
│   ├── LIQUIDITY_FORECAST.ipynb           # Main LCR calculations
│   ├── LIQUIDITY_WHAT_IF_FORECAST_SANDBOX.ipynb  # Scenario testing
│   ├── prod_calculations.py               # Core LCR functions
│   └── utils.py                           # What-if helpers
└── streamlit/
    └── app.py             # 3-page dashboard (LCR, What-If, Agent Chat)
```

### Key Technologies

| Technology | Purpose |
|------------|---------|
| Snowpark Python | DataFrame-based calculations |
| Streamlit in Snowflake | Interactive dashboard |
| Cortex Analyst | Natural language to SQL |
| Semantic Views | Business-friendly data model |
| Cortex Agent | AI assistant for queries |

### Data Flow

1. **Raw data** (positions, cash flows, counterparties)
2. **Notebook calculations** (HQLA projection, cash flow projection, LCR formula)
3. **Presentation tables**
4. **Streamlit dashboard** with Cortex Agent chat

---

## Liquidity Risk: Key Concepts for Non-Finance Folks

### What is Liquidity?

**Liquidity** = How quickly you can convert an asset to cash without losing value.

| Asset | Liquidity Level |
|-------|-----------------|
| Cash in your wallet | Highest - it's already cash |
| Savings account | Very high - withdraw anytime |
| Stocks | High - sell in minutes |
| Real estate | Low - takes weeks/months to sell |

### What is Liquidity Risk?

**Liquidity Risk** = The danger that a bank can't pay its short-term obligations when they come due.

**Simple analogy:** Imagine you have $1 million in a house but only $100 in your bank account. If your rent is due tomorrow for $2,000, you have a liquidity problem—you're wealthy but can't pay your immediate bills.

### Why Does This Matter for Banks?

Banks face a fundamental mismatch:
- **Deposits** (liabilities): Customers can withdraw anytime
- **Loans** (assets): Locked up for years (mortgages, business loans)

If too many customers withdraw at once (a "bank run"), the bank may not have enough cash—even if it's technically profitable.

### The 2008 Financial Crisis Connection

During 2008, banks couldn't meet short-term obligations even though they had assets. This led to:
- Bank failures (Lehman Brothers)
- Government bailouts
- New regulations (Basel III)

---

## Basel III & LCR

### What is Basel III?

International banking regulations created after 2008 to prevent future crises. One key requirement: **Banks must hold enough liquid assets to survive 30 days of stress.**

### What is LCR (Liquidity Coverage Ratio)?

```
LCR = High-Quality Liquid Assets (HQLA) / Net Cash Outflows (30 days)
```

| Term | Meaning |
|------|---------|
| **HQLA** | Assets easily converted to cash (government bonds, cash reserves) |
| **Net Cash Outflows** | Money going out minus money coming in over 30 days |
| **Minimum LCR** | 100% (must have enough to cover 30 days of outflows) |

**Example:**
- HQLA: $150 million
- Net Outflows (30 days): $100 million
- LCR = 150 / 100 = **150%** (Above 100% minimum)

### HQLA Levels (Quality Tiers)

| Level | Examples | Haircut | Why |
|-------|----------|---------|-----|
| **Level 1** | Cash, government bonds | 0% | Most liquid, safest |
| **Level 2A** | Corporate bonds (AA-rated) | 15% | Slightly less liquid |
| **Level 2B** | Lower-rated bonds, some stocks | 25-50% | Can lose value in crisis |

**Haircut** = A discount applied because assets may lose value when you need to sell them quickly during a crisis.

---

## Basel III Applicability to Norway

**Yes, Basel III regulations (including LCR) are applicable to Norwegian banks.**

### Why It Applies

| Factor | Details |
|--------|---------|
| **EEA Membership** | Norway is part of the European Economic Area (EEA) |
| **EU Regulations** | EEA countries adopt EU financial regulations |
| **CRR/CRD** | Basel III is implemented in EU/EEA via the Capital Requirements Regulation (CRR) and Capital Requirements Directive (CRD IV/V) |
| **Finanstilsynet** | Norway's Financial Supervisory Authority enforces these rules |

### Key Requirements for Norwegian Banks

| Requirement | Minimum | Purpose |
|-------------|---------|---------|
| **LCR** (Liquidity Coverage Ratio) | ≥100% | 30-day liquidity buffer |
| **NSFR** (Net Stable Funding Ratio) | ≥100% | 1-year funding stability |
| **Capital Ratios** | ~14%+ CET1 | Loss absorption capacity |

### Norwegian Banks & LCR

Major Norwegian banks like **DNB, SpareBank 1, and Nordea (Norway operations)** must:
- Report LCR to Finanstilsynet
- Maintain LCR ≥ 100% at all times
- Hold HQLA (primarily Norwegian government bonds, cash)

### Norway-Specific Considerations

Norway has some additional requirements:
- **Countercyclical buffer**: Norway has been a leader in setting higher buffers (currently 2.5%)
- **Systemic risk buffer**: Additional requirements for systemically important banks
- Norwegian government bonds qualify as **Level 1 HQLA**

---

## What-If Scenario Analysis

The what-if analysis lets banks answer: **"What happens to our LCR if market conditions change?"**

### How It Works (Step by Step)

```
┌─────────────────────────────────────────────────────────────────────┐
│  1. CLONE DATA                                                      │
│     Create temporary copies of POSITIONS, CASH_INFLOWS, OUTFLOWS    │
│     (Original data stays untouched)                                 │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  2. LOOK UP ADJUSTMENT FACTORS                                      │
│     From WHAT_IF_DEFINITIONS_LOOKUP table                           │
│     Example: "European Institutional counterparties → -15%"         │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  3. APPLY FACTORS TO CLONED DATA                                    │
│     Multiply values by adjustment factors (e.g., 0.85 for -15%)     │
└─────────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────┐
│  4. RECALCULATE LCR                                                 │
│     Run same HQLA + cash flow projections on adjusted data          │
│     → New LCR shows impact of stress scenario                       │
└─────────────────────────────────────────────────────────────────────┘
```

### Example Scenarios (from setup.sql)

**Scenario 1** (`WHAT_IF_ID = 1`):

| Target | Filter | Adjustment |
|--------|--------|------------|
| Counterparties | Region = Europe | **-10%** |
| Counterparties | Type = Institutional | **-15%** |
| Positions | Security = AAA Gov Bonds | **-5%** |
| Positions | Security = Main Index Equities | **-10%** |
| Cash Inflows | Region = North America | **-10%** |
| Cash Outflows | Region = North America | **-5%** |

**Scenario 2** (`WHAT_IF_ID = 2`): More severe, adds:
- Asia region counterparties: **-15%**
- European cash inflows: **-20%**
- Trading business unit cash flows: **-10%**

### What the Code Does

1. **`clone_and_update()`** - Creates sandbox copies and applies factors:
   ```
   Original Position Value: $1,000,000
   × Business Unit Factor (Treasury, -5%): 0.95
   × Security Type Factor (AAA Bonds, -5%): 0.95
   = Stressed Position Value: $902,500
   ```

2. **Factors are multiplicative** - Multiple conditions compound:
   ```python
   # From utils.py line 39
   REDUCE(ARRAY_AGG(FACTOR), 1, (acc, x) -> acc * x)
   ```

3. **Same LCR calculation** runs on stressed data → shows how much LCR drops

### Real-World Use Case

| Scenario | Question Answered |
|----------|-------------------|
| European crisis | "If European counterparties face 10-15% stress, does our LCR stay above 100%?" |
| Regional downturn | "If North American cash flows drop 10%, can we still meet obligations?" |
| Asset devaluation | "If equity markets drop 10%, how much HQLA do we lose?" |

### Result

The analysis outputs to `PRESENTATION.WHAT_IF_LCR`:
- **Original LCR**: 150%
- **Stressed LCR (Scenario 1)**: 125% (still above 100%)
- **Stressed LCR (Scenario 2)**: 98% (below regulatory minimum!)

This helps banks identify vulnerabilities before a real crisis hits.

---

## Setup Instructions

### Run Setup with Snow CLI

```bash
snow sql -f scripts/setup.sql -c <connection_name>
```

### Prerequisites

1. Snowflake connection must have **ACCOUNTADMIN** access
2. The script will create:
   - Role: `LIQUIDITY_RISK_ROLE`
   - Warehouse: `LIQUIDITY_RISK_WH` (Medium)
   - Database: `LIQUIDITY_RISK_DB`

### Two-Step Process

The script has a **manual step** (Section 10) - upload files to stages **before** running sections 11-13.

```bash
# Step 1: Run setup (sections 1-9 will work, 11-13 will fail without files)
snow sql -f scripts/setup.sql -c <connection_name>

# Step 2: Upload notebook files
snow stage copy notebooks/LIQUIDITY_FORECAST.ipynb @LIQUIDITY_RISK_DB.NOTEBOOKS.LIQUIDITY_NOTEBOOK_STAGE -c <connection_name> --overwrite
snow stage copy notebooks/LIQUIDITY_WHAT_IF_FORECAST_SANDBOX.ipynb @LIQUIDITY_RISK_DB.NOTEBOOKS.LIQUIDITY_NOTEBOOK_STAGE -c <connection_name> --overwrite
snow stage copy notebooks/environment.yml @LIQUIDITY_RISK_DB.NOTEBOOKS.LIQUIDITY_NOTEBOOK_STAGE -c <connection_name> --overwrite
snow stage copy notebooks/prod_calculations.py @LIQUIDITY_RISK_DB.NOTEBOOKS.LIQUIDITY_NOTEBOOK_STAGE -c <connection_name> --overwrite
snow stage copy notebooks/utils.py @LIQUIDITY_RISK_DB.NOTEBOOKS.LIQUIDITY_NOTEBOOK_STAGE -c <connection_name> --overwrite

# Step 3: Upload streamlit files
snow stage copy streamlit/app.py @LIQUIDITY_RISK_DB.STREAMLIT.LIQUIDITY_STREAMLIT_STAGE -c <connection_name> --overwrite
snow stage copy streamlit/environment.yml @LIQUIDITY_RISK_DB.STREAMLIT.LIQUIDITY_STREAMLIT_STAGE -c <connection_name> --overwrite

# Step 4: Re-run setup to create notebooks/streamlit/semantic view (sections 11-13)
snow sql -f scripts/setup.sql -c <connection_name>
```

### Cleanup

```bash
snow sql -f scripts/teardown.sql -c <connection_name>
```

---

## Quick Reference

| Concept | One-Liner |
|---------|-----------|
| **Liquidity** | How fast can you get cash? |
| **Liquidity Risk** | Danger of not having cash when needed |
| **Basel III** | Post-2008 banking safety rules |
| **LCR** | 30-day cash survival ratio (must be ≥100%) |
| **HQLA** | High-quality assets you can sell fast |
| **Stress Testing** | "What if?" scenarios to test resilience |
