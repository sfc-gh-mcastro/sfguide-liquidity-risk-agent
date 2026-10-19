# Liquidity Risk Dashboard (LCR Agent Demo)

Next.js app for the Liquidity Coverage Ratio (LCR) demo. It shows the LCR dashboard, the What-If stress scenarios, and a docked **Ask the Agent** pane that calls the Cortex Agent `LIQUIDITY_RISK_DB.PUBLIC.LIQUIDITY_FORECAST_AGENT`.

- **Snowflake connection:** any named connection that can use `LIQUIDITY_RISK_ROLE` (examples use `<your_connection>`)
- **Role:** `LIQUIDITY_RISK_ROLE`
- **Database:** `LIQUIDITY_RISK_DB`
- **Warehouse:** `LIQUIDITY_RISK_WH`

## Prerequisites

- Node.js and npm
- Snowflake CLI configured with a named connection in `~/.snowflake/config.toml` (or `connections.toml`), whose user can use `LIQUIDITY_RISK_ROLE`
- The LCR environment deployed on `<your_connection>` on that connection (`../scripts/setup.sql`)

## Run locally

```bash
cd liquidity-risk-app
npm ci --legacy-peer-deps
SNOWFLAKE_CONNECTION_NAME=<your_connection> npm run dev -- -p 3123
```

Open http://localhost:3123.

### Why the flags matter

- **`SNOWFLAKE_CONNECTION_NAME=<your_connection>`:** without it the app uses `default_connection_name` from `config.toml`, which may point at a different account. It overrides the file default (`lib/snowflake.ts`).
- **`--legacy-peer-deps`:** a plain `npm install`/`npm ci` can crash on Node 23 / npm 10.9 with `Cannot read properties of null (reading 'edgesOut')`.
- **`-p 3123`:** the port the demo notes use. Any free port works.

## Pages

| Path | What it shows |
|---|---|
| `/` | LCR dashboard: Day-1 metrics, 150-day trend, re-calculate button |
| `/what-if` | Pre-defined stress scenarios and their LCR results |

The agent pane is docked on the right on both pages, so the conversation carries over between them. Use the header button to collapse it, and the floating **Ask the Agent** button to bring it back.

## Demo questions (one-click starters in the pane)

1. What is the current LCR and how does it trend over the next 30 days? (~15s)
2. Break down our HQLA by asset category. Which categories hold the most value? (~60s, talk over the Generated SQL from Q1 while it runs)
3. Compare the baseline with the what-if stress scenario. (~20s)
4. On which day does the LCR drop below 15x? (the agent pushes back: the LCR rises through 15x, it never drops below it)

## Check the agent without the UI

```bash
curl -s -X POST http://localhost:3123/api/agent \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","text":"What is the current LCR?"}]}'
```

Returns `answer`, `sql` (the generated SQL) and `suggestions`.

## Troubleshooting

- **Wrong data or "object does not exist":** the app is probably on the wrong connection. Restart with `SNOWFLAKE_CONNECTION_NAME=<your_connection>`.
- **What-If page is empty:** run the what-if notebook once (as `LIQUIDITY_RISK_ROLE`):
  ```sql
  EXECUTE NOTEBOOK LIQUIDITY_RISK_DB.PUBLIC.LIQUIDITY_WHAT_IF_FORECAST_SANDBOX(
    'db=LIQUIDITY_RISK_DB',
    'positions_table=LIQUIDITY_RISK_DB.RAW_SANDBOX.POSITIONS',
    'inflows_table=LIQUIDITY_RISK_DB.RAW_SANDBOX.CASH_INFLOWS',
    'outflows_table=LIQUIDITY_RISK_DB.RAW_SANDBOX.CASH_OUTFLOWS',
    'suffix=DEMO01', 'what_if_id=1');
  ```
- **Agent pane errors:** use Snowflake Intelligence in Snowsight as the fallback; the agent is registered there.

## Deploy to Snowflake (SAR)

```bash
snow app deploy --connection <your_connection> --role LIQUIDITY_RISK_ROLE
```

Deploys `LIQUIDITY_RISK_DB.PUBLIC.LIQUIDITY_RISK_DASHBOARD` as `LIQUIDITY_RISK_ROLE` (settings in `snowflake.yml`).

## Cleanup

```sql
DROP APPLICATION SERVICE IF EXISTS LIQUIDITY_RISK_DB.PUBLIC.LIQUIDITY_RISK_DASHBOARD;
DROP DATABASE IF EXISTS LIQUIDITY_RISK_DB;
DROP WAREHOUSE IF EXISTS LIQUIDITY_RISK_WH;
DROP WAREHOUSE IF EXISTS LIQUIDITY_RISK_AGENT_WH;
DROP ROLE IF EXISTS LIQUIDITY_RISK_ROLE;
```

After teardown, check that the `LIQUIDITY_RISK_DASHBOARD_REPO` artifact repository is gone too.
