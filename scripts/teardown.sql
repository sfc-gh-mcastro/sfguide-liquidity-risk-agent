-- Copyright 2026 Snowflake Inc.
-- SPDX-License-Identifier: Apache-2.0
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
-- http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

-- =====================================================
-- Liquidity Risk Agent - Full Teardown Script
-- =====================================================
-- This script removes all objects created by setup.sql
-- Run with ACCOUNTADMIN role
-- =====================================================

USE ROLE ACCOUNTADMIN;

-- Remove agent from Snowflake Intelligence
BEGIN
    ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT 
      DROP AGENT LIQUIDITY_RISK_DB.PUBLIC.LIQUIDITY_FORECAST_AGENT;
EXCEPTION
    WHEN OTHER THEN NULL;
END;

-- Drop database (cascades all schemas, tables, stages, notebooks, streamlit, semantic views, agents, procedures)
DROP DATABASE IF EXISTS LIQUIDITY_RISK_DB;

-- Drop warehouses
DROP WAREHOUSE IF EXISTS LIQUIDITY_RISK_WH;
DROP WAREHOUSE IF EXISTS LIQUIDITY_RISK_AGENT_WH;

-- Revoke account-level privileges from role before dropping (wrapped to handle if role/grants don't exist)
BEGIN
    REVOKE CREATE SNOWFLAKE INTELLIGENCE ON ACCOUNT FROM ROLE LIQUIDITY_RISK_ROLE;
EXCEPTION
    WHEN OTHER THEN NULL;
END;

BEGIN
    REVOKE CREATE DATABASE ON ACCOUNT FROM ROLE LIQUIDITY_RISK_ROLE;
EXCEPTION
    WHEN OTHER THEN NULL;
END;

BEGIN
    REVOKE CREATE WAREHOUSE ON ACCOUNT FROM ROLE LIQUIDITY_RISK_ROLE;
EXCEPTION
    WHEN OTHER THEN NULL;
END;

-- Revoke Snowflake Intelligence permissions
BEGIN
    REVOKE USAGE ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT FROM ROLE LIQUIDITY_RISK_ROLE;
EXCEPTION
    WHEN OTHER THEN NULL;
END;

BEGIN
    REVOKE MODIFY ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT FROM ROLE LIQUIDITY_RISK_ROLE;
EXCEPTION
    WHEN OTHER THEN NULL;
END;

-- Revoke database role
BEGIN
    REVOKE DATABASE ROLE SNOWFLAKE.CORTEX_USER FROM ROLE LIQUIDITY_RISK_ROLE;
EXCEPTION
    WHEN OTHER THEN NULL;
END;

-- Drop the role
USE ROLE USERADMIN;
DROP ROLE IF EXISTS LIQUIDITY_RISK_ROLE;

-- =====================================================
-- Verification: Confirm objects are removed
-- =====================================================
-- SHOW DATABASES LIKE 'LIQUIDITY_RISK_DB';
-- SHOW WAREHOUSES LIKE 'LIQUIDITY_RISK%';
-- SHOW ROLES LIKE 'LIQUIDITY_RISK_ROLE';
