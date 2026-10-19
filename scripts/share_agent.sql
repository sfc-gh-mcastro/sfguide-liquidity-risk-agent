-- Copyright 2026 Snowflake Inc.
-- SPDX-License-Identifier: Apache-2.0
--
-- =====================================================
-- Liquidity Risk Agent - Share the agent with another account
-- =====================================================
-- Shares the Liquidity Forecast Agent, its semantic view and the tables
-- the semantic view reads, then (optionally) creates a reader account to
-- consume it. A reader account lets you show the consumer side of sharing
-- without a second Snowflake account. Reader accounts receive direct
-- shares only; they cannot install Marketplace listings.
--
-- Run setup.sql first. Replace every <...> placeholder before running.
-- =====================================================

-- =====================================================
-- SECTION 1: Provider - create the share
-- =====================================================
USE ROLE ACCOUNTADMIN;

CREATE SHARE IF NOT EXISTS LCR_AGENT_SHARE
    COMMENT = 'Liquidity Forecast Agent + semantic view + data';

GRANT USAGE ON DATABASE LIQUIDITY_RISK_DB TO SHARE LCR_AGENT_SHARE;
GRANT USAGE ON SCHEMA LIQUIDITY_RISK_DB.PUBLIC TO SHARE LCR_AGENT_SHARE;
GRANT USAGE ON SCHEMA LIQUIDITY_RISK_DB.RAW TO SHARE LCR_AGENT_SHARE;
GRANT USAGE ON SCHEMA LIQUIDITY_RISK_DB.PRESENTATION TO SHARE LCR_AGENT_SHARE;

-- Tables referenced by LIQUIDITY_SV, granted one by one so what-if
-- working tables in RAW are not exposed to the consumer
GRANT SELECT ON TABLE LIQUIDITY_RISK_DB.RAW.ASSET_CLASSIFICATIONS TO SHARE LCR_AGENT_SHARE;
GRANT SELECT ON TABLE LIQUIDITY_RISK_DB.RAW.BUSINESS_UNIT_REFERENCE TO SHARE LCR_AGENT_SHARE;
GRANT SELECT ON TABLE LIQUIDITY_RISK_DB.RAW.CASH_INFLOWS TO SHARE LCR_AGENT_SHARE;
GRANT SELECT ON TABLE LIQUIDITY_RISK_DB.RAW.CASH_OUTFLOWS TO SHARE LCR_AGENT_SHARE;
GRANT SELECT ON TABLE LIQUIDITY_RISK_DB.RAW.COUNTERPARTY_DATA TO SHARE LCR_AGENT_SHARE;
GRANT SELECT ON TABLE LIQUIDITY_RISK_DB.RAW.HQLA_SUMMARY TO SHARE LCR_AGENT_SHARE;
GRANT SELECT ON TABLE LIQUIDITY_RISK_DB.RAW.POSITIONS TO SHARE LCR_AGENT_SHARE;
GRANT SELECT ON TABLE LIQUIDITY_RISK_DB.RAW.WHAT_IF_DEFINITIONS_LOOKUP TO SHARE LCR_AGENT_SHARE;
GRANT SELECT ON TABLE LIQUIDITY_RISK_DB.PRESENTATION.LCR TO SHARE LCR_AGENT_SHARE;
GRANT SELECT ON TABLE LIQUIDITY_RISK_DB.PRESENTATION.WHAT_IF_LCR TO SHARE LCR_AGENT_SHARE;

-- AI objects
GRANT SELECT, REFERENCES ON SEMANTIC VIEW LIQUIDITY_RISK_DB.PUBLIC.LIQUIDITY_SV TO SHARE LCR_AGENT_SHARE;
GRANT USAGE ON AGENT LIQUIDITY_RISK_DB.PUBLIC.LIQUIDITY_FORECAST_AGENT TO SHARE LCR_AGENT_SHARE;

SHOW GRANTS TO SHARE LCR_AGENT_SHARE;

-- To publish on Snowflake Marketplace instead, attach LCR_AGENT_SHARE to a
-- listing in Provider Studio and add the "Cortex AI Ready" category.

-- =====================================================
-- SECTION 2: Provider - create a reader account (optional)
-- =====================================================
-- The provider pays for all compute used in the reader account.
CREATE MANAGED ACCOUNT LCR_READER
    ADMIN_NAME = LCR_READER_ADMIN,
    ADMIN_PASSWORD = '<strong_password>',
    TYPE = READER,
    COMMENT = 'Consumer for the Liquidity Forecast Agent share';

-- Note the accountLocator in the output, wait up to 5 minutes for
-- provisioning, then add the reader account to the share
ALTER SHARE LCR_AGENT_SHARE ADD ACCOUNTS = <reader_account_locator>;

-- =====================================================
-- SECTION 3: Reader account - consume the share
-- =====================================================
-- Sign in to the reader account URL as LCR_READER_ADMIN and run:
--
-- USE ROLE ACCOUNTADMIN;
-- -- Keep the database name: the agent spec references
-- -- LIQUIDITY_RISK_DB.PUBLIC.LIQUIDITY_SV by full name
-- CREATE DATABASE LIQUIDITY_RISK_DB FROM SHARE <provider_account_locator>.LCR_AGENT_SHARE;
--
-- CREATE WAREHOUSE READER_WH WAREHOUSE_SIZE = XSMALL AUTO_SUSPEND = 60
--     AUTO_RESUME = TRUE INITIALLY_SUSPENDED = TRUE;
-- CREATE RESOURCE MONITOR READER_RM WITH CREDIT_QUOTA = 5 FREQUENCY = MONTHLY
--     START_TIMESTAMP = IMMEDIATELY
--     TRIGGERS ON 90 PERCENT DO SUSPEND ON 100 PERCENT DO SUSPEND_IMMEDIATE;
-- ALTER WAREHOUSE READER_WH SET RESOURCE_MONITOR = READER_RM;
-- ALTER USER LCR_READER_ADMIN SET DEFAULT_WAREHOUSE = READER_WH;
--
-- SHOW AGENTS IN SCHEMA LIQUIDITY_RISK_DB.PUBLIC;
--
-- -- Ask the shared agent a question
-- USE WAREHOUSE READER_WH;
-- SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
--     'LIQUIDITY_RISK_DB.PUBLIC.LIQUIDITY_FORECAST_AGENT',
--     $${"stream":false,"messages":[{"role":"user","content":[{"type":"text","text":"What is the current LCR on day 1?"}]}]}$$);

-- =====================================================
-- SECTION 4: Teardown (uncomment to clean up)
-- =====================================================
-- A dropped reader account counts against the limit for 7 days.
-- DROP MANAGED ACCOUNT LCR_READER;
-- DROP SHARE LCR_AGENT_SHARE;
