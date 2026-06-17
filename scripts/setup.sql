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
-- Liquidity Risk Agent - Snowflake Guide Setup
-- =====================================================
-- This script sets up the complete environment for the
-- Liquidity Coverage Ratio (LCR) analysis guide
--
-- Variables:
--   PREFIX: LIQUIDITY_RISK
--   DATABASE: LIQUIDITY_RISK_DB
--   WAREHOUSE: LIQUIDITY_RISK_WH
--   ROLE: LIQUIDITY_RISK_ROLE
-- =====================================================

-- Set query tag for solution tracking
ALTER SESSION SET query_tag = '{"origin":"sf_sit-is","name":"liquidity_risk_agent","version":{"major":1,"minor":0},"attributes":{"is_quickstart":1,"source":"sql"}}';

-- =====================================================
-- SECTION 1: Role Setup
-- =====================================================
USE ROLE USERADMIN;
CREATE OR REPLACE ROLE LIQUIDITY_RISK_ROLE;
GRANT ROLE LIQUIDITY_RISK_ROLE TO ROLE SYSADMIN;

USE ROLE ACCOUNTADMIN;
GRANT CREATE SNOWFLAKE INTELLIGENCE ON ACCOUNT TO ROLE LIQUIDITY_RISK_ROLE;
CREATE SNOWFLAKE INTELLIGENCE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;
GRANT USAGE ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT TO ROLE LIQUIDITY_RISK_ROLE;
GRANT MODIFY ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT TO ROLE LIQUIDITY_RISK_ROLE;
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE LIQUIDITY_RISK_ROLE;
GRANT CREATE DATABASE ON ACCOUNT TO ROLE LIQUIDITY_RISK_ROLE;
GRANT CREATE WAREHOUSE ON ACCOUNT TO ROLE LIQUIDITY_RISK_ROLE;

-- =====================================================
-- SECTION 2: Warehouse Setup
-- =====================================================
USE ROLE LIQUIDITY_RISK_ROLE;

CREATE OR REPLACE WAREHOUSE LIQUIDITY_RISK_WH
WITH 
    WAREHOUSE_SIZE = 'MEDIUM'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    RESOURCE_CONSTRAINT = STANDARD_GEN_2;

GRANT USAGE ON WAREHOUSE LIQUIDITY_RISK_WH TO ROLE LIQUIDITY_RISK_ROLE;

-- =====================================================
-- SECTION 3: Database & Schemas Setup
-- =====================================================
CREATE OR REPLACE DATABASE LIQUIDITY_RISK_DB;
CREATE OR REPLACE SCHEMA LIQUIDITY_RISK_DB.RAW;
CREATE OR REPLACE SCHEMA LIQUIDITY_RISK_DB.TRANSFORMED;
CREATE OR REPLACE SCHEMA LIQUIDITY_RISK_DB.PRESENTATION;
CREATE OR REPLACE SCHEMA LIQUIDITY_RISK_DB.RAW_SANDBOX;
GRANT CREATE SEMANTIC VIEW ON SCHEMA LIQUIDITY_RISK_DB.PUBLIC TO ROLE LIQUIDITY_RISK_ROLE;

USE DATABASE LIQUIDITY_RISK_DB;
USE SCHEMA RAW;
USE WAREHOUSE LIQUIDITY_RISK_WH;

-- =====================================================
-- SECTION 4: Stages Setup
-- =====================================================
CREATE SCHEMA IF NOT EXISTS LIQUIDITY_RISK_DB.NOTEBOOKS;
CREATE STAGE IF NOT EXISTS LIQUIDITY_RISK_DB.NOTEBOOKS.LIQUIDITY_NOTEBOOK_STAGE;

CREATE SCHEMA IF NOT EXISTS LIQUIDITY_RISK_DB.STREAMLIT;
CREATE STAGE IF NOT EXISTS LIQUIDITY_RISK_DB.STREAMLIT.LIQUIDITY_STREAMLIT_STAGE;

-- =====================================================
-- SECTION 5: Raw Schema Tables
-- =====================================================
USE SCHEMA RAW;

-- Reference Tables
CREATE OR REPLACE TABLE COUNTERPARTY_DATA (
    COUNTERPARTY_ID VARCHAR(50) NOT NULL,
    COUNTERPARTY_NAME VARCHAR(200) NOT NULL,
    COUNTERPARTY_TYPE VARCHAR(50),
    CREDIT_RATING VARCHAR(10),
    REGION VARCHAR(50),
    IS_ACTIVE BOOLEAN DEFAULT TRUE,
    CREATED_DATE TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (COUNTERPARTY_ID)
);

CREATE OR REPLACE TABLE BUSINESS_UNIT_REFERENCE (
    BUSINESS_UNIT_ID VARCHAR(20) NOT NULL,
    BUSINESS_UNIT_NAME VARCHAR(100) NOT NULL,
    BUSINESS_UNIT_TYPE VARCHAR(50),
    REGION VARCHAR(50),
    IS_ACTIVE BOOLEAN DEFAULT TRUE,
    CREATED_DATE TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (BUSINESS_UNIT_ID)
);

CREATE OR REPLACE TABLE ASSET_CLASSIFICATIONS (
    SECURITY_TYPE VARCHAR(50) PRIMARY KEY,
    HQLA_LEVEL VARCHAR(10) NOT NULL,
    HAIRCUT_PERCENT DECIMAL(5,2) NOT NULL,
    DESCRIPTION VARCHAR(500),
    REGULATORY_BASIS VARCHAR(200),
    CREATED_DATE TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE CURRENCY_REFERENCE (
    CURRENCY_CODE VARCHAR(3) PRIMARY KEY,
    CURRENCY_NAME VARCHAR(100) NOT NULL,
    IS_MAJOR_CURRENCY BOOLEAN DEFAULT FALSE,
    FX_RATE_USD DECIMAL(15,6),
    LAST_UPDATED TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE STRESS_SCENARIOS (
    SCENARIO_ID VARCHAR(20) PRIMARY KEY,
    SCENARIO_NAME VARCHAR(100) NOT NULL,
    SCENARIO_TYPE VARCHAR(50),
    DESCRIPTION VARCHAR(500),
    IS_ACTIVE BOOLEAN DEFAULT TRUE,
    CREATED_DATE TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE WHAT_IF_DEFINITIONS_LOOKUP (
    WHAT_IF_ID VARCHAR(20) PRIMARY KEY,
    WHAT_IF_NAME VARCHAR(100) NOT NULL,
    REF_TBL VARCHAR(100) NOT NULL,
    TBL VARCHAR(100) NOT NULL,
    COL VARCHAR(100) NOT NULL,
    VAL VARCHAR(100) NOT NULL,
    FACTOR FLOAT NOT NULL,
    CREATED_DATE TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- Fact Tables
CREATE OR REPLACE TABLE POSITIONS (
    POSITION_ID VARCHAR(50) NOT NULL,
    BUSINESS_UNIT_ID VARCHAR(20) NOT NULL,
    SECURITY_ID VARCHAR(50) NOT NULL,
    SECURITY_TYPE VARCHAR(50) NOT NULL,
    POSITION_TYPE VARCHAR(20) NOT NULL,
    QUANTITY NUMBER(20,4) NOT NULL,
    POSITION_VALUE_USD NUMBER(20,2) NOT NULL,
    POSITION_DATE DATE NOT NULL,
    MATURITY_DATE DATE,
    CREATED_DATE TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (POSITION_ID)
);

CREATE OR REPLACE TABLE CASH_INFLOWS (
    INFLOW_ID VARCHAR(50) NOT NULL,
    BUSINESS_UNIT_ID VARCHAR(20) NOT NULL,
    COUNTERPARTY_ID VARCHAR(50) NOT NULL,
    INFLOW_TYPE VARCHAR(50) NOT NULL,
    INFLOW_AMOUNT_USD NUMBER(20,2) NOT NULL,
    MATURITY_DATE DATE,
    POSITION_DATE DATE NOT NULL,
    CREATED_DATE TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (INFLOW_ID)
);

CREATE OR REPLACE TABLE CASH_OUTFLOWS (
    OUTFLOW_ID VARCHAR(50) NOT NULL,
    BUSINESS_UNIT_ID VARCHAR(20) NOT NULL,
    COUNTERPARTY_ID VARCHAR(50) NOT NULL,
    OUTFLOW_TYPE VARCHAR(50) NOT NULL,
    OUTFLOW_AMOUNT_USD NUMBER(20,2) NOT NULL,
    MATURITY_DATE DATE,
    POSITION_DATE DATE NOT NULL,
    CREATED_DATE TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (OUTFLOW_ID)
);

CREATE OR REPLACE TABLE MARKET_DATA (
    SECURITY_ID VARCHAR(50) NOT NULL,
    SECURITY_TYPE VARCHAR(50),
    PRICE_USD NUMBER(20,4),
    MARKET_DATE DATE NOT NULL,
    CREATED_DATE TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (SECURITY_ID)
);

CREATE OR REPLACE TRANSIENT TABLE HQLA_SUMMARY (
    DAY_NUMBER NUMBER(38,0),
    TOTAL_HQLA_USD NUMBER(38,2)
);

CREATE OR REPLACE TRANSIENT TABLE HQLA_DETAIL (
    MATURITY_DATE DATE,
    TOTAL_HQLA_USD NUMBER(32,10)
);

-- =====================================================
-- SECTION 6: Load Reference Data
-- =====================================================
INSERT INTO ASSET_CLASSIFICATIONS (SECURITY_TYPE, HQLA_LEVEL, HAIRCUT_PERCENT, DESCRIPTION, REGULATORY_BASIS)
SELECT SECURITY_TYPE, HQLA_LEVEL, HAIRCUT_PERCENT, DESCRIPTION, REGULATORY_BASIS
FROM VALUES
    ('CASH', 'Level 1', 0.00, 'Cash and central bank reserves', 'Basel III Article 416'),
    ('CENTRAL_BANK_RESERVES', 'Level 1', 0.00, 'Central bank reserves', 'Basel III Article 416'),
    ('GOVERNMENT_BONDS_AAA', 'Level 1', 0.00, 'Government bonds rated AAA', 'Basel III Article 416'),
    ('GOVERNMENT_BONDS_AA', 'Level 1', 0.00, 'Government bonds rated AA', 'Basel III Article 416'),
    ('GOVERNMENT_BONDS_A', 'Level 1', 0.00, 'Government bonds rated A', 'Basel III Article 416'),
    ('CORPORATE_BONDS_AA', 'Level 2A', 15.00, 'Corporate bonds rated AA', 'Basel III Article 417'),
    ('COVERED_BONDS_AA', 'Level 2A', 15.00, 'Covered bonds rated AA', 'Basel III Article 417'),
    ('MUNICIPAL_BONDS_AA', 'Level 2A', 15.00, 'Municipal bonds rated AA', 'Basel III Article 417'),
    ('CORPORATE_BONDS_A', 'Level 2A', 15.00, 'Corporate bonds rated A', 'Basel III Article 417'),
    ('CORPORATE_BONDS_BBB', 'Level 2B', 25.00, 'Corporate bonds rated BBB', 'Basel III Article 418'),
    ('EQUITIES_MAIN_INDEX', 'Level 2B', 25.00, 'Equities included in main stock index', 'Basel III Article 418'),
    ('EQUITIES_OTHER', 'Level 2B', 50.00, 'Other equities', 'Basel III Article 418'),
    ('COVERED_BONDS_BBB', 'Level 2B', 25.00, 'Covered bonds rated BBB', 'Basel III Article 418')
AS v(SECURITY_TYPE, HQLA_LEVEL, HAIRCUT_PERCENT, DESCRIPTION, REGULATORY_BASIS);

INSERT INTO CURRENCY_REFERENCE (CURRENCY_CODE, CURRENCY_NAME, IS_MAJOR_CURRENCY, FX_RATE_USD) VALUES
('USD', 'US Dollar', TRUE, 1.000000),
('EUR', 'Euro', TRUE, 0.920000),
('GBP', 'British Pound', TRUE, 0.790000),
('JPY', 'Japanese Yen', TRUE, 150.000000),
('CHF', 'Swiss Franc', TRUE, 0.880000),
('CAD', 'Canadian Dollar', TRUE, 1.350000),
('AUD', 'Australian Dollar', TRUE, 1.500000),
('CNY', 'Chinese Yuan', TRUE, 7.200000),
('HKD', 'Hong Kong Dollar', FALSE, 7.800000),
('SGD', 'Singapore Dollar', FALSE, 1.350000);

INSERT INTO BUSINESS_UNIT_REFERENCE (BUSINESS_UNIT_ID, BUSINESS_UNIT_NAME, BUSINESS_UNIT_TYPE, REGION) VALUES
('GLOBAL', 'Global Bank', 'Group', 'Global'),
('US_TREASURY', 'US Treasury', 'Treasury', 'North America'),
('EU_TREASURY', 'EU Treasury', 'Treasury', 'Europe'),
('ASIA_TREASURY', 'Asia Treasury', 'Treasury', 'Asia'),
('US_TRADING', 'US Trading', 'Trading', 'North America'),
('EU_TRADING', 'EU Trading', 'Trading', 'Europe'),
('ASIA_TRADING', 'Asia Trading', 'Trading', 'Asia'),
('INVESTMENT_BANKING', 'Investment Banking', 'Investment Banking', 'Global'),
('WEALTH_MANAGEMENT', 'Wealth Management', 'Wealth Management', 'Global');

INSERT INTO COUNTERPARTY_DATA (COUNTERPARTY_ID, COUNTERPARTY_NAME, COUNTERPARTY_TYPE, CREDIT_RATING, REGION)
SELECT 
    'CP_' || LPAD(SEQ8()::STRING, 6, '0') AS COUNTERPARTY_ID,
    'Counterparty ' || (SEQ8() + 1)::STRING AS COUNTERPARTY_NAME,
    CASE (SEQ8() % 4) WHEN 0 THEN 'Bank' WHEN 1 THEN 'Corporate' WHEN 2 THEN 'Sovereign' ELSE 'Institutional' END,
    CASE (SEQ8() % 5) WHEN 0 THEN 'AAA' WHEN 1 THEN 'AA' WHEN 2 THEN 'A' WHEN 3 THEN 'BBB' ELSE 'BB' END,
    CASE (SEQ8() % 3) WHEN 0 THEN 'North America' WHEN 1 THEN 'Europe' ELSE 'Asia' END
FROM TABLE(GENERATOR(ROWCOUNT => 2000));

INSERT INTO STRESS_SCENARIOS (SCENARIO_ID, SCENARIO_NAME, SCENARIO_TYPE, DESCRIPTION) VALUES
('BASEL_STANDARD', 'Basel III Standard Scenario', 'Basel III', 'Standard Basel III stress scenario'),
('MARKET_CRISIS', 'Market Crisis Scenario', 'Custom', 'Severe market stress scenario'),
('LIQUIDITY_CRISIS', 'Liquidity Crisis Scenario', 'Custom', 'Extreme liquidity stress scenario');

INSERT INTO WHAT_IF_DEFINITIONS_LOOKUP (WHAT_IF_ID, WHAT_IF_NAME, REF_TBL, TBL, COL, VAL, FACTOR) VALUES
('1','TEST','COUNTERPARTY_DATA','COUNTERPARTY_DATA','REGION','Europe',-0.1),
('1','TEST','COUNTERPARTY_DATA','COUNTERPARTY_DATA','COUNTERPARTY_TYPE','Institutional',-0.15),
('1','TEST','POSITIONS','ASSET_CLASSIFICATIONS','SECURITY_TYPE','GOVERNMENT_BONDS_AAA',-0.05),
('1','TEST','POSITIONS','ASSET_CLASSIFICATIONS','SECURITY_TYPE','EQUITIES_MAIN_INDEX',-0.1),
('1','TEST','POSITIONS','BUSINESS_UNIT_REFERENCE','BUSINESS_UNIT_TYPE','Treasury',-0.05),
('1','TEST','CASH_INFLOWS','BUSINESS_UNIT_REFERENCE','BUSINESS_UNIT_TYPE','Treasury',-0.02),
('1','TEST','CASH_INFLOWS','BUSINESS_UNIT_REFERENCE','REGION','North America',-0.1),
('1','TEST','CASH_OUTFLOWS','BUSINESS_UNIT_REFERENCE','BUSINESS_UNIT_TYPE','Treasury',-0.01),
('1','TEST','CASH_OUTFLOWS','BUSINESS_UNIT_REFERENCE','REGION','North America',-0.05),

('2','TEST2','COUNTERPARTY_DATA','COUNTERPARTY_DATA','REGION','Europe',-0.1),
('2','TEST2','COUNTERPARTY_DATA','COUNTERPARTY_DATA','REGION','Asia',-0.15),
('2','TEST2','COUNTERPARTY_DATA','COUNTERPARTY_DATA','COUNTERPARTY_TYPE','Institutional',-0.15),
('2','TEST2','COUNTERPARTY_DATA','COUNTERPARTY_DATA','COUNTERPARTY_TYPE','Bank',-0.05),
('2','TEST2','POSITIONS','ASSET_CLASSIFICATIONS','SECURITY_TYPE','GOVERNMENT_BONDS_AAA',-0.05),
('2','TEST2','POSITIONS','ASSET_CLASSIFICATIONS','SECURITY_TYPE','EQUITIES_MAIN_INDEX',-0.1),
('2','TEST2','POSITIONS','BUSINESS_UNIT_REFERENCE','BUSINESS_UNIT_TYPE','Treasury',-0.05),
('2','TEST2','CASH_INFLOWS','BUSINESS_UNIT_REFERENCE','BUSINESS_UNIT_TYPE','Investment Banking',-0.02),
('2','TEST2','CASH_INFLOWS','BUSINESS_UNIT_REFERENCE','BUSINESS_UNIT_TYPE','Trading',-0.1),
('2','TEST2','CASH_INFLOWS','BUSINESS_UNIT_REFERENCE','REGION','Europe',-0.2),
('2','TEST2','CASH_OUTFLOWS','BUSINESS_UNIT_REFERENCE','BUSINESS_UNIT_TYPE','Trading',-0.01),
('2','TEST2','CASH_OUTFLOWS','BUSINESS_UNIT_REFERENCE','REGION','Europe',-0.05);

-- =====================================================
-- SECTION 7: Generate Sample Data
-- =====================================================
INSERT INTO MARKET_DATA (SECURITY_ID, SECURITY_TYPE, PRICE_USD, MARKET_DATE)
WITH MARKET_DATA_REFERENCE AS (
SELECT 
    'SEC_' || LPAD((SEQ8())::STRING, 6, '0') AS SECURITY_ID,
    CASE (SEQ8() % 8)
        WHEN 0 THEN 'GOVERNMENT_BOND' WHEN 1 THEN 'GOVERNMENT_BOND' WHEN 2 THEN 'GOVERNMENT_BOND'
        WHEN 3 THEN 'CORPORATE_BOND' WHEN 4 THEN 'CORPORATE_BOND' WHEN 5 THEN 'EQUITY'
        WHEN 6 THEN 'DERIVATIVE' ELSE 'MONEY_MARKET'
    END AS SECURITY_TYPE,
    100.00 + (UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) * 900)::DECIMAL(20,4) AS PRICE_USD,
    CURRENT_DATE() AS MARKET_DATE
FROM TABLE(GENERATOR(ROWCOUNT => 10000)) 
)
SELECT B.SECURITY_ID, B.SECURITY_TYPE, B.PRICE_USD * UNIFORM(.98, 1.0199, RANDOM()) AS PRICE_USD, 
       CURRENT_DATE() - A.DAY AS MARKET_DATE
FROM (SELECT SEQ8() AS DAY FROM TABLE(GENERATOR(ROWCOUNT => 365))) a
     JOIN MARKET_DATA_REFERENCE b
ORDER BY SECURITY_ID, MARKET_DATE;

INSERT INTO POSITIONS (POSITION_ID, BUSINESS_UNIT_ID, SECURITY_ID, SECURITY_TYPE, POSITION_TYPE, QUANTITY, 
                       POSITION_VALUE_USD, POSITION_DATE, MATURITY_DATE)
WITH POSITION_REFERENCE AS (
    SELECT 
        'POS_' || LPAD(SEQ8()::STRING, 8, '0') AS POSITION_ID,
        CASE (SEQ8() % 9)
            WHEN 0 THEN 'US_TRADING' WHEN 1 THEN 'US_TREASURY' WHEN 2 THEN 'EU_TRADING'
            WHEN 3 THEN 'EU_TREASURY' WHEN 4 THEN 'ASIA_TRADING' WHEN 5 THEN 'ASIA_TREASURY'
            WHEN 6 THEN 'GLOBAL' WHEN 7 THEN 'INVESTMENT_BANKING' ELSE 'WEALTH_MANAGEMENT'
        END AS BUSINESS_UNIT_ID,
        'SEC_' || LPAD((SEQ8() % 10000)::STRING, 6, '0') AS SECURITY_ID,
        CASE (SEQ8() % 2) WHEN 0 THEN 'Long' ELSE 'Short' END AS POSITION_TYPE,
        (1 + UNIFORM(1, 5.01::FLOAT, RANDOM()) * 99)::DECIMAL(20,4) AS QUANTITY,
        (100000 + UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) * 9900000)::DECIMAL(20,2) AS MARKET_VALUE_USD,
        CURRENT_DATE() - (SEQ8() % 365) AS POSITION_DATE,
        CASE (SEQ8() % 3)
            WHEN 0 THEN NULL
            ELSE CURRENT_DATE() + (SEQ8() % 730)
        END AS MATURITY_DATE
    FROM TABLE(GENERATOR(ROWCOUNT => 500000))
)
SELECT a.POSITION_ID, a.BUSINESS_UNIT_ID, a.SECURITY_ID, b.SECURITY_TYPE, a.POSITION_TYPE, 
       a.QUANTITY, a.QUANTITY * b.PRICE_USD as POSITION_VALUE_USD, a.POSITION_DATE, a.MATURITY_DATE
FROM POSITION_REFERENCE a
JOIN MARKET_DATA b ON a.SECURITY_ID = b.SECURITY_ID AND a.POSITION_DATE = b.market_date
UNION
SELECT 'POS_' || LPAD((SEQ8()+500000)::STRING, 8, '0'),
       CASE (SEQ8() % 9)
           WHEN 0 THEN 'US_TRADING' WHEN 1 THEN 'US_TREASURY' WHEN 2 THEN 'EU_TRADING'
           WHEN 3 THEN 'EU_TREASURY' WHEN 4 THEN 'ASIA_TRADING' WHEN 5 THEN 'ASIA_TREASURY'
           WHEN 6 THEN 'GLOBAL' WHEN 7 THEN 'INVESTMENT_BANKING' ELSE 'WEALTH_MANAGEMENT'
       END,
       'CASH_' || LPAD((SEQ8())::STRING, 6, '0'),
       CASE (SEQ8() % 2) WHEN 0 THEN 'CASH' ELSE 'CENTRAL_BANK_RESERVES' END,
       'Long', 1, (10000 + (UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) * 9900000))::DECIMAL(20,2),
       CURRENT_DATE() - (SEQ8() % 365), NULL
FROM TABLE(GENERATOR(ROWCOUNT => 80000));

INSERT INTO CASH_INFLOWS (INFLOW_ID, BUSINESS_UNIT_ID, COUNTERPARTY_ID, INFLOW_TYPE, INFLOW_AMOUNT_USD, MATURITY_DATE, POSITION_DATE)
SELECT 
    'INFLOW_' || LPAD(SEQ8()::STRING, 8, '0'),
    CASE (SEQ8() % 9)
        WHEN 0 THEN 'US_TRADING' WHEN 1 THEN 'US_TREASURY' WHEN 2 THEN 'EU_TRADING'
        WHEN 3 THEN 'EU_TREASURY' WHEN 4 THEN 'ASIA_TRADING' WHEN 5 THEN 'ASIA_TREASURY'
        WHEN 6 THEN 'GLOBAL' WHEN 7 THEN 'INVESTMENT_BANKING' ELSE 'WEALTH_MANAGEMENT'
    END,
    'CP_' || LPAD((SEQ8() % 2000)::STRING, 6, '0'),
    CASE (SEQ8() % 4) WHEN 0 THEN 'DEPOSIT' WHEN 1 THEN 'LOAN_REPAYMENT' WHEN 2 THEN 'INTEREST_PAYMENT' ELSE 'OTHER' END,
    (1000000 + UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) * 990000000)::DECIMAL(20,2) / uniform(1200, 1600, random()),
    CASE 
        WHEN (SEQ8() % 10) = 0 THEN NULL
        WHEN (SEQ8() % 10) < 4 THEN CURRENT_DATE() + (SEQ8() % 90)
        WHEN (SEQ8() % 10) < 7 THEN CURRENT_DATE() + 90 + (SEQ8() % 90)
        WHEN (SEQ8() % 10) < 9 THEN CURRENT_DATE() + 180 + (SEQ8() % 185)
        ELSE CURRENT_DATE() + 365 + (SEQ8() % 365)
    END,
    CURRENT_DATE() - (SEQ8() % 365)
FROM TABLE(GENERATOR(ROWCOUNT => 100000));

INSERT INTO CASH_OUTFLOWS (OUTFLOW_ID, BUSINESS_UNIT_ID, COUNTERPARTY_ID, OUTFLOW_TYPE, OUTFLOW_AMOUNT_USD, MATURITY_DATE, POSITION_DATE)
SELECT 
    'OUTFLOW_' || LPAD(SEQ8()::STRING, 8, '0'),
    CASE (SEQ8() % 9)
        WHEN 0 THEN 'US_TRADING' WHEN 1 THEN 'US_TREASURY' WHEN 2 THEN 'EU_TRADING'
        WHEN 3 THEN 'EU_TREASURY' WHEN 4 THEN 'ASIA_TRADING' WHEN 5 THEN 'ASIA_TREASURY'
        WHEN 6 THEN 'GLOBAL' WHEN 7 THEN 'INVESTMENT_BANKING' ELSE 'WEALTH_MANAGEMENT'
    END,
    'CP_' || LPAD((SEQ8() % 2000)::STRING, 6, '0'),
    CASE (SEQ8() % 4) WHEN 0 THEN 'DEPOSIT' WHEN 1 THEN 'LOAN_REPAYMENT' WHEN 2 THEN 'INTEREST_PAYMENT' ELSE 'OTHER' END,
    (1000000 + UNIFORM(0::FLOAT, 1::FLOAT, RANDOM()) * 990000000)::DECIMAL(20,2) / uniform(1200, 1600, random()),
    CASE 
        WHEN (SEQ8() % 10) = 0 THEN NULL
        WHEN (SEQ8() % 10) < 4 THEN CURRENT_DATE() + (SEQ8() % 90)
        WHEN (SEQ8() % 10) < 7 THEN CURRENT_DATE() + 90 + (SEQ8() % 90)
        WHEN (SEQ8() % 10) < 9 THEN CURRENT_DATE() + 180 + (SEQ8() % 185)
        ELSE CURRENT_DATE() + 365 + (SEQ8() % 365)
    END,
    CURRENT_DATE() - (SEQ8() % 365)
FROM TABLE(GENERATOR(ROWCOUNT => 100000));

-- =====================================================
-- SECTION 8: RAW_SANDBOX Schema (Sandbox Tables)
-- =====================================================
USE SCHEMA RAW_SANDBOX;

CREATE OR REPLACE TABLE POSITIONS CLONE LIQUIDITY_RISK_DB.RAW.POSITIONS;
CREATE OR REPLACE TABLE CASH_INFLOWS CLONE LIQUIDITY_RISK_DB.RAW.CASH_INFLOWS;
CREATE OR REPLACE TABLE CASH_OUTFLOWS CLONE LIQUIDITY_RISK_DB.RAW.CASH_OUTFLOWS;
CREATE OR REPLACE TABLE COUNTERPARTY_DATA CLONE LIQUIDITY_RISK_DB.RAW.COUNTERPARTY_DATA;
CREATE OR REPLACE TABLE BUSINESS_UNIT_REFERENCE CLONE LIQUIDITY_RISK_DB.RAW.BUSINESS_UNIT_REFERENCE;
CREATE OR REPLACE TABLE ASSET_CLASSIFICATIONS CLONE LIQUIDITY_RISK_DB.RAW.ASSET_CLASSIFICATIONS;
CREATE OR REPLACE TABLE WHAT_IF_DEFINITIONS_LOOKUP CLONE LIQUIDITY_RISK_DB.RAW.WHAT_IF_DEFINITIONS_LOOKUP;
CREATE OR REPLACE TRANSIENT TABLE HQLA_SUMMARY CLONE LIQUIDITY_RISK_DB.RAW.HQLA_SUMMARY;
CREATE OR REPLACE TRANSIENT TABLE HQLA_DETAIL CLONE LIQUIDITY_RISK_DB.RAW.HQLA_DETAIL;

-- =====================================================
-- SECTION 9: Presentation Schema Tables
-- =====================================================
USE SCHEMA PRESENTATION;

CREATE OR REPLACE TABLE LIQUIDITY_RISK_DB.PRESENTATION.LCR (
    CREATED_TIMESTAMP TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
    DAY_NUMBER NUMBER(38,0),
    TOTAL_NET_CASH_OUTFLOWS NUMBER(38,2),
    HQLA NUMBER(38,10),
    LCR NUMBER(38,12)
);

CREATE OR REPLACE TABLE LIQUIDITY_RISK_DB.PRESENTATION.WHAT_IF_LCR (
    WHAT_IF_ID VARCHAR(50),
    CREATED_TIMESTAMP TIMESTAMP_NTZ(9) DEFAULT CURRENT_TIMESTAMP(),
    DAY_NUMBER NUMBER(38,0),
    TOTAL_NET_CASH_OUTFLOWS NUMBER(38,2),
    HQLA NUMBER(38,10),
    LCR NUMBER(38,12)
);

-- =====================================================
-- SECTION 10: PUT Instructions
-- =====================================================
-- Upload notebook and streamlit files to stages using SnowSQL or Snowsight:
--
 PUT file://notebooks/LIQUIDITY_FORECAST.ipynb @LIQUIDITY_RISK_DB.NOTEBOOKS.LIQUIDITY_NOTEBOOK_STAGE auto_compress = false overwrite = true;
 PUT file://notebooks/LIQUIDITY_WHAT_IF_FORECAST_SANDBOX.ipynb @LIQUIDITY_RISK_DB.NOTEBOOKS.LIQUIDITY_NOTEBOOK_STAGE auto_compress = false overwrite = true;
 PUT file://notebooks/environment.yml @LIQUIDITY_RISK_DB.NOTEBOOKS.LIQUIDITY_NOTEBOOK_STAGE auto_compress = false overwrite = true;
 PUT file://notebooks/prod_calculations.py @LIQUIDITY_RISK_DB.NOTEBOOKS.LIQUIDITY_NOTEBOOK_STAGE auto_compress = false overwrite = true;
 PUT file://notebooks/utils.py @LIQUIDITY_RISK_DB.NOTEBOOKS.LIQUIDITY_NOTEBOOK_STAGE auto_compress = false overwrite = true;

 PUT file://streamlit/app.py @LIQUIDITY_RISK_DB.STREAMLIT.LIQUIDITY_STREAMLIT_STAGE auto_compress = false overwrite = true;
 PUT file://streamlit/environment.yml @LIQUIDITY_RISK_DB.STREAMLIT.LIQUIDITY_STREAMLIT_STAGE auto_compress = false overwrite = true;

-- =====================================================
-- SECTION 11: Create Notebooks
-- =====================================================
CREATE OR REPLACE NOTEBOOK LIQUIDITY_RISK_DB.PUBLIC.LIQUIDITY_FORECAST
    FROM '@LIQUIDITY_RISK_DB.NOTEBOOKS.LIQUIDITY_NOTEBOOK_STAGE'
    MAIN_FILE = 'LIQUIDITY_FORECAST.ipynb'
    QUERY_WAREHOUSE = 'LIQUIDITY_RISK_WH';

ALTER NOTEBOOK LIQUIDITY_RISK_DB.PUBLIC.LIQUIDITY_FORECAST ADD LIVE VERSION FROM LAST;

CREATE OR REPLACE NOTEBOOK LIQUIDITY_RISK_DB.PUBLIC.LIQUIDITY_WHAT_IF_FORECAST_SANDBOX
    FROM '@LIQUIDITY_RISK_DB.NOTEBOOKS.LIQUIDITY_NOTEBOOK_STAGE'
    MAIN_FILE = 'LIQUIDITY_WHAT_IF_FORECAST_SANDBOX.ipynb'
    QUERY_WAREHOUSE = 'LIQUIDITY_RISK_WH';

ALTER NOTEBOOK LIQUIDITY_RISK_DB.PUBLIC.LIQUIDITY_WHAT_IF_FORECAST_SANDBOX ADD LIVE VERSION FROM LAST;

-- =====================================================
-- SECTION 12: Create Streamlit App
-- =====================================================
CREATE OR REPLACE STREAMLIT LIQUIDITY_RISK_DB.PUBLIC.LIQUIDITY_STREAMLIT
    FROM @LIQUIDITY_RISK_DB.STREAMLIT.LIQUIDITY_STREAMLIT_STAGE
    MAIN_FILE = 'app.py'
    QUERY_WAREHOUSE = 'LIQUIDITY_RISK_WH';

-- =====================================================
-- SECTION 13: Semantic View & Agent Setup
-- =====================================================
USE SCHEMA PUBLIC;

-- Create the semantic view with DDL syntax
-- Note: This is a large YAML definition that defines the LIQUIDITY_SV semantic view
-- for natural language queries against liquidity data
CALL SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML(
'LIQUIDITY_RISK_DB.PUBLIC',
$$
name: LIQUIDITY_SV
description: This Semantic View connects to raw and presentation schemas for Liquidity analysis
tables:
  - name: ASSET_CLASSIFICATIONS
    description: This table stores the classification details of various security types, including their High-Quality Liquid Asset (HQLA) level, haircut percentage, and regulatory basis, to support risk management and regulatory compliance in financial institutions.
    base_table:
      database: LIQUIDITY_RISK_DB
      schema: RAW
      table: ASSET_CLASSIFICATIONS
    dimensions:
      - name: DESCRIPTION
        description: The type of investment or asset classification, such as cash, central bank reserves, or government bonds.
        expr: DESCRIPTION
        data_type: VARCHAR(500)
      - name: HQLA_LEVEL
        description: High-Quality Liquid Asset (HQLA) classification levels as defined by Basel III regulations.
        expr: HQLA_LEVEL
        data_type: VARCHAR(10)
      - name: REGULATORY_BASIS
        description: This column categorizes assets based on the specific article of the Basel III regulatory framework.
        expr: REGULATORY_BASIS
        data_type: VARCHAR(200)
      - name: SECURITY_TYPE
        description: The type of security or asset classification.
        expr: SECURITY_TYPE
        data_type: VARCHAR(50)
    time_dimensions:
      - name: CREATED_DATE
        description: Date and time when the asset classification was created.
        expr: CREATED_DATE
        data_type: TIMESTAMP_NTZ(9)
    facts:
      - name: HAIRCUT_PERCENT
        description: The percentage reduction in value applied to a specific asset class.
        expr: HAIRCUT_PERCENT
        data_type: NUMBER(5,2)
    primary_key:
      columns:
        - SECURITY_TYPE
  - name: BUSINESS_UNIT_REFERENCE
    description: This table stores reference information for business units within an organization.
    base_table:
      database: LIQUIDITY_RISK_DB
      schema: RAW
      table: BUSINESS_UNIT_REFERENCE
    dimensions:
      - name: BUSINESS_UNIT_ID
        description: Identifies the business unit to which the transaction or account belongs.
        expr: BUSINESS_UNIT_ID
        data_type: VARCHAR(20)
      - name: BUSINESS_UNIT_NAME
        description: The name of the business unit within the organization.
        expr: BUSINESS_UNIT_NAME
        data_type: VARCHAR(100)
      - name: BUSINESS_UNIT_TYPE
        description: The type of business unit (Treasury, Group, Trading, etc.).
        expr: BUSINESS_UNIT_TYPE
        data_type: VARCHAR(50)
      - name: IS_ACTIVE
        description: Indicates whether the business unit is currently active.
        expr: IS_ACTIVE
        data_type: BOOLEAN
      - name: REGION
        description: Geographic region where the business unit operates.
        expr: REGION
        data_type: VARCHAR(50)
    time_dimensions:
      - name: CREATED_DATE
        description: Date and time when the business unit reference was created.
        expr: CREATED_DATE
        data_type: TIMESTAMP_NTZ(9)
    primary_key:
      columns:
        - BUSINESS_UNIT_ID
  - name: CASH_INFLOWS
    description: This table stores information about incoming cash flows for a business.
    base_table:
      database: LIQUIDITY_RISK_DB
      schema: RAW
      table: CASH_INFLOWS
    dimensions:
      - name: BUSINESS_UNIT_ID
        description: Identifies the business unit associated with the cash inflow.
        expr: BUSINESS_UNIT_ID
        data_type: VARCHAR(20)
      - name: COUNTERPARTY_ID
        description: Unique identifier for the counterparty involved in the cash inflow transaction.
        expr: COUNTERPARTY_ID
        data_type: VARCHAR(50)
      - name: INFLOW_ID
        description: Unique identifier for a specific cash inflow transaction.
        expr: INFLOW_ID
        data_type: VARCHAR(50)
      - name: INFLOW_TYPE
        description: The type of cash inflow transaction (DEPOSIT, LOAN_REPAYMENT, INTEREST_PAYMENT, OTHER).
        expr: INFLOW_TYPE
        data_type: VARCHAR(50)
    time_dimensions:
      - name: CREATED_DATE
        description: Date and time when the cash inflow record was created.
        expr: CREATED_DATE
        data_type: TIMESTAMP_NTZ(9)
      - name: MATURITY_DATE
        description: The date on which a cash inflow is expected to be received.
        expr: MATURITY_DATE
        data_type: DATE
      - name: POSITION_DATE
        description: Date when a cash inflow position was recorded.
        expr: POSITION_DATE
        data_type: DATE
    facts:
      - name: INFLOW_AMOUNT_USD
        description: The amount of cash received by the company, measured in US dollars.
        expr: INFLOW_AMOUNT_USD
        data_type: NUMBER(20,2)
    primary_key:
      columns:
        - INFLOW_ID
  - name: CASH_OUTFLOWS
    description: This table stores information about cash outflows.
    base_table:
      database: LIQUIDITY_RISK_DB
      schema: RAW
      table: CASH_OUTFLOWS
    dimensions:
      - name: BUSINESS_UNIT_ID
        description: Identifies the business unit responsible for the cash outflow.
        expr: BUSINESS_UNIT_ID
        data_type: VARCHAR(20)
      - name: COUNTERPARTY_ID
        description: Unique identifier for the counterparty involved in the cash outflow transaction.
        expr: COUNTERPARTY_ID
        data_type: VARCHAR(50)
      - name: OUTFLOW_ID
        description: Unique identifier for a cash outflow transaction.
        expr: OUTFLOW_ID
        data_type: VARCHAR(50)
      - name: OUTFLOW_TYPE
        description: The type of cash outflow transaction (DEPOSIT, LOAN_REPAYMENT, INTEREST_PAYMENT, OTHER).
        expr: OUTFLOW_TYPE
        data_type: VARCHAR(50)
    time_dimensions:
      - name: CREATED_DATE
        description: Date and time when the cash outflow was recorded.
        expr: CREATED_DATE
        data_type: TIMESTAMP_NTZ(9)
      - name: MATURITY_DATE
        description: The date on which a financial obligation or debt is due for payment.
        expr: MATURITY_DATE
        data_type: DATE
      - name: POSITION_DATE
        description: Date on which a cash outflow position was recorded.
        expr: POSITION_DATE
        data_type: DATE
    facts:
      - name: OUTFLOW_AMOUNT_USD
        description: The total amount of cash outflows in US dollars.
        expr: OUTFLOW_AMOUNT_USD
        data_type: NUMBER(20,2)
    primary_key:
      columns:
        - OUTFLOW_ID
  - name: COUNTERPARTY_DATA
    description: This table stores information about counterparties.
    base_table:
      database: LIQUIDITY_RISK_DB
      schema: RAW
      table: COUNTERPARTY_DATA
    dimensions:
      - name: COUNTERPARTY_ID
        description: Unique identifier for a counterparty.
        expr: COUNTERPARTY_ID
        data_type: VARCHAR(50)
      - name: COUNTERPARTY_NAME
        description: The name of the counterparty entity.
        expr: COUNTERPARTY_NAME
        data_type: VARCHAR(200)
      - name: COUNTERPARTY_TYPE
        description: The type of entity (Sovereign, Bank, Corporate, Institutional).
        expr: COUNTERPARTY_TYPE
        data_type: VARCHAR(50)
      - name: CREDIT_RATING
        description: The credit rating assigned to a counterparty (AAA, AA, A, BBB, BB).
        expr: CREDIT_RATING
        data_type: VARCHAR(10)
      - name: IS_ACTIVE
        description: Indicates whether the counterparty is currently active.
        expr: IS_ACTIVE
        data_type: BOOLEAN
      - name: REGION
        description: Geographic region where the counterparty is located.
        expr: REGION
        data_type: VARCHAR(50)
    time_dimensions:
      - name: CREATED_DATE
        description: Date and time when the counterparty data was created.
        expr: CREATED_DATE
        data_type: TIMESTAMP_NTZ(9)
    primary_key:
      columns:
        - COUNTERPARTY_ID
  - name: HQLA_SUMMARY
    description: This table stores daily summaries of High-Quality Liquid Assets (HQLA) in USD.
    base_table:
      database: LIQUIDITY_RISK_DB
      schema: RAW
      table: HQLA_SUMMARY
    dimensions:
      - name: DAY_NUMBER
        description: Day of the year for which the HQLA summary is reported.
        expr: DAY_NUMBER
        data_type: NUMBER(38,0)
    facts:
      - name: TOTAL_HQLA_USD
        description: Total High-Quality Liquid Assets (HQLA) value in US Dollars.
        expr: TOTAL_HQLA_USD
        data_type: NUMBER(38,2)
  - name: LCR
    description: This table stores Liquidity Coverage Ratio (LCR) data for assessing short-term liquidity needs.
    base_table:
      database: LIQUIDITY_RISK_DB
      schema: PRESENTATION
      table: LCR
    dimensions:
      - name: DAY_NUMBER
        description: The day number for the LCR forecast.
        expr: DAY_NUMBER
        data_type: NUMBER(38,0)
    time_dimensions:
      - name: CREATED_TIMESTAMP
        description: The date and time when the record was created.
        expr: CREATED_TIMESTAMP
        data_type: TIMESTAMP_NTZ(9)
    facts:
      - name: HQLA
        description: High-Quality Liquid Assets value.
        expr: HQLA
        data_type: NUMBER(38,10)
      - name: LCR
        description: Liquidity Coverage Ratio.
        expr: LCR
        data_type: NUMBER(38,12)
      - name: TOTAL_NET_CASH_OUTFLOWS
        description: The total amount of cash outflows.
        expr: TOTAL_NET_CASH_OUTFLOWS
        data_type: NUMBER(38,2)
  - name: POSITIONS
    description: This table stores information about investment positions held by various business units.
    base_table:
      database: LIQUIDITY_RISK_DB
      schema: RAW
      table: POSITIONS
    dimensions:
      - name: BUSINESS_UNIT_ID
        description: Identifies the treasury business unit to which the position belongs.
        expr: BUSINESS_UNIT_ID
        data_type: VARCHAR(20)
      - name: POSITION_ID
        description: Unique identifier for a specific position.
        expr: POSITION_ID
        data_type: VARCHAR(50)
      - name: POSITION_TYPE
        description: The type of position held (Long or Short).
        expr: POSITION_TYPE
        data_type: VARCHAR(20)
      - name: SECURITY_ID
        description: Unique identifier for a security.
        expr: SECURITY_ID
        data_type: VARCHAR(50)
      - name: SECURITY_TYPE
        description: The type of security being held.
        expr: SECURITY_TYPE
        data_type: VARCHAR(50)
    time_dimensions:
      - name: CREATED_DATE
        description: Date and time when the position was created.
        expr: CREATED_DATE
        data_type: TIMESTAMP_NTZ(9)
      - name: MATURITY_DATE
        description: The date on which a financial instrument is scheduled to mature.
        expr: MATURITY_DATE
        data_type: DATE
      - name: POSITION_DATE
        description: Date when the position was established or last updated.
        expr: POSITION_DATE
        data_type: DATE
    facts:
      - name: POSITION_VALUE_USD
        description: The total value of a position in US dollars.
        expr: POSITION_VALUE_USD
        data_type: NUMBER(20,2)
      - name: QUANTITY
        description: The quantity held.
        expr: QUANTITY
        data_type: NUMBER(20,4)
    primary_key:
      columns:
        - POSITION_ID
  - name: WHAT_IF_DEFINITIONS_LOOKUP
    description: This table stores definitions for what-if scenarios used for analysis or forecasting.
    base_table:
      database: LIQUIDITY_RISK_DB
      schema: RAW
      table: WHAT_IF_DEFINITIONS_LOOKUP
    dimensions:
      - name: COL
        description: Column name for the what-if filter.
        expr: COL
        data_type: VARCHAR(100)
      - name: REF_TBL
        description: Reference table used for data validation.
        expr: REF_TBL
        data_type: VARCHAR(100)
      - name: TBL
        description: Target table name.
        expr: TBL
        data_type: VARCHAR(100)
      - name: VAL
        description: The filter value.
        expr: VAL
        data_type: VARCHAR(100)
      - name: WHAT_IF_ID
        description: Unique identifier for a what-if scenario definition.
        expr: WHAT_IF_ID
        data_type: VARCHAR(20)
      - name: WHAT_IF_NAME
        description: The name of the what-if scenario.
        expr: WHAT_IF_NAME
        data_type: VARCHAR(100)
    time_dimensions:
      - name: CREATED_DATE
        description: Date and time when the what-if definition was created.
        expr: CREATED_DATE
        data_type: TIMESTAMP_NTZ(9)
    facts:
      - name: FACTOR
        description: Factor to be applied to the calculation.
        expr: FACTOR
        data_type: FLOAT
    primary_key:
      columns:
        - WHAT_IF_ID
  - name: WHAT_IF_LCR
    description: This table stores LCR data for hypothetical scenarios or stress tests.
    base_table:
      database: LIQUIDITY_RISK_DB
      schema: PRESENTATION
      table: WHAT_IF_LCR
    dimensions:
      - name: DAY_NUMBER
        description: The day number for the scenario.
        expr: DAY_NUMBER
        data_type: NUMBER(38,0)
      - name: WHAT_IF_ID
        description: Unique identifier for a what-if scenario.
        expr: WHAT_IF_ID
        data_type: VARCHAR(50)
    time_dimensions:
      - name: CREATED_TIMESTAMP
        description: The date and time when the record was created.
        expr: CREATED_TIMESTAMP
        data_type: TIMESTAMP_NTZ(9)
    facts:
      - name: HQLA
        description: High-Quality Liquid Assets value for the scenario.
        expr: HQLA
        data_type: NUMBER(38,10)
      - name: LCR
        description: Liquidity Coverage Ratio for the scenario.
        expr: LCR
        data_type: NUMBER(38,12)
      - name: TOTAL_NET_CASH_OUTFLOWS
        description: The total amount of cash outflows for the scenario.
        expr: TOTAL_NET_CASH_OUTFLOWS
        data_type: NUMBER(38,2)
relationships:
  - name: INFLOW_COUNTERPARTY
    left_table: CASH_INFLOWS
    right_table: COUNTERPARTY_DATA
    relationship_columns:
      - left_column: COUNTERPARTY_ID
        right_column: COUNTERPARTY_ID
  - name: OUTFLOW_BUSINESS_UNIT
    left_table: CASH_OUTFLOWS
    right_table: BUSINESS_UNIT_REFERENCE
    relationship_columns:
      - left_column: BUSINESS_UNIT_ID
        right_column: BUSINESS_UNIT_ID
  - name: OUTFLOW_COUNTERPARTY
    left_table: CASH_OUTFLOWS
    right_table: COUNTERPARTY_DATA
    relationship_columns:
      - left_column: COUNTERPARTY_ID
        right_column: COUNTERPARTY_ID
  - name: POSITIONS_TO_ASSET_SECURITY_TYPE
    left_table: POSITIONS
    right_table: ASSET_CLASSIFICATIONS
    relationship_columns:
      - left_column: SECURITY_TYPE
        right_column: SECURITY_TYPE
  - name: POSITION_BUSINESS_UNIT
    left_table: POSITIONS
    right_table: BUSINESS_UNIT_REFERENCE
    relationship_columns:
      - left_column: BUSINESS_UNIT_ID
        right_column: BUSINESS_UNIT_ID
verified_queries:
  - name: What is the liquidity coverage ratio trend over time?
    question: What is the liquidity coverage ratio trend over time along with the underlying cash outflows and high-quality liquid assets?
    sql: |
      SELECT
        lcr.day_number AS day_number,
        lcr.total_net_cash_outflows AS total_net_cash_outflows,
        lcr.hqla AS hqla,
        lcr.lcr AS lcr
      FROM
        lcr AS lcr
      WHERE lcr.created_timestamp IN (SELECT max(created_timestamp) FROM LIQUIDITY_RISK_DB.PRESENTATION.LCR)
      ORDER BY
        lcr.day_number ASC NULLS FIRST
    verified_by: Snowflake Guide
    verified_at: 1764067774
  - name: What is contributing to the increase in LCR over the next 150 days?
    question: What is contributing to the increase in LCR over the next 150 days?
    sql: |-
      SELECT
        day_number,
        hqla,
        total_net_cash_outflows,
        lcr,
        hqla - LAG(hqla) OVER (ORDER BY day_number) AS hqla_change,
        total_net_cash_outflows - LAG(total_net_cash_outflows) OVER (ORDER BY day_number) AS outflows_change,
        lcr - LAG(lcr) OVER (ORDER BY day_number) AS lcr_change
      FROM
        lcr
      WHERE
        day_number <= 150
        and CREATED_TIMESTAMP = (select max(CREATED_TIMESTAMP) from lcr)
      ORDER BY
        day_number ASC
    verified_by: Snowflake Guide
    verified_at: 1764068119
$$
);

-- Create a dedicated warehouse for the agent
CREATE WAREHOUSE IF NOT EXISTS LIQUIDITY_RISK_AGENT_WH
WITH 
    WAREHOUSE_SIZE = 'MEDIUM'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE;

GRANT USAGE ON WAREHOUSE LIQUIDITY_RISK_AGENT_WH TO ROLE LIQUIDITY_RISK_ROLE;

-- Create the Liquidity Forecast Agent
CREATE OR REPLACE AGENT LIQUIDITY_RISK_DB.PUBLIC.LIQUIDITY_FORECAST_AGENT
WITH PROFILE='{ "display_name": "Liquidity Forecast Agent" }'
  COMMENT=$$ This agent analyzes liquidity positions and forecasts using Cortex Analyst with the LIQUIDITY_SV semantic view. It can calculate Liquidity Coverage Ratios (LCR), analyze High-Quality Liquid Assets (HQLA), evaluate cash inflows and outflows, run what-if scenarios, and provide insights on Basel III regulatory compliance. $$
FROM SPECIFICATION
$$
{
    "models": {
      "orchestration": "auto"
    },
    "instructions": {
      "response": "Provide clear, actionable insights about liquidity positions and forecasts. When presenting financial metrics, format numbers appropriately (e.g., use millions/billions for large amounts). Include relevant context about Basel III regulations when discussing LCR thresholds.",
      "orchestration": "You are a liquidity risk management agent specializing in Liquidity Coverage Ratio (LCR) analysis and forecasting.\n\nYour primary capabilities:\n\n1. **LCR Analysis**: Calculate and analyze Liquidity Coverage Ratios across different time horizons (30-day, 60-day, 90-day, and up to 150-day forecasts). The regulatory minimum LCR is typically 100%.\n\n2. **HQLA Composition**: Analyze High-Quality Liquid Assets by:\n   - Level 1 assets (cash, central bank reserves, government bonds) - 0% haircut\n   - Level 2A assets (corporate bonds AA, covered bonds AA) - 15% haircut\n   - Level 2B assets (corporate bonds BBB, equities) - 25-50% haircut\n\n3. **Cash Flow Analysis**: Examine cash inflows and outflows by:\n   - Business unit (US Treasury, EU Treasury, Asia Treasury, Trading units)\n   - Counterparty type (Bank, Corporate, Sovereign, Institutional)\n   - Flow type (Deposit, Loan Repayment, Interest Payment)\n   - Maturity buckets\n\n4. **What-If Scenarios**: Run stress tests and hypothetical scenarios to assess liquidity impact under different conditions. Compare baseline LCR with scenario-adjusted LCR.\n\n5. **Regulatory Compliance**: Provide insights aligned with Basel III LCR requirements and stress testing frameworks.\n\nWhen answering questions:\n- Use the LIQUIDITY_ANALYST tool for all quantitative queries about positions, cash flows, HQLA, and LCR metrics\n- Always consider the most recent data (use CREATED_TIMESTAMP for LCR and WHAT_IF_LCR tables)\n- When comparing scenarios, clearly show baseline vs stressed metrics\n- Produce charts when visualizing trends over time (e.g., LCR forecast curves)\n- Flag any LCR values below 100% as potential regulatory concerns",
      "sample_questions": [
        {"question": "What's LCR today and headroom vs floor?"},
        {"question": "Why did LCR move? What are top 3 causes?"},
        {"question": "7/30 days - where's LCR heading?"},
        {"question": "Intraday alerts: Any surprises now?"}
      ]
    },
    "tools": [
      {
        "tool_spec": {
          "type": "cortex_analyst_text_to_sql",
          "name": "LIQUIDITY_ANALYST",
          "description": "SEMANTIC VIEW: LIQUIDITY_SV\nDATABASE: LIQUIDITY_RISK_DB\nSCHEMA: PUBLIC\n\nThis semantic view provides comprehensive access to liquidity management data for Basel III Liquidity Coverage Ratio (LCR) analysis and forecasting.\n\n**CORE TABLES:**\n\n1. LCR (Presentation Schema)\n   - Primary LCR calculations with 150-day forecasts\n   - Columns: DAY_NUMBER, TOTAL_NET_CASH_OUTFLOWS, HQLA, LCR, CREATED_TIMESTAMP\n   - Use CREATED_TIMESTAMP to get the most recent forecast run\n\n2. WHAT_IF_LCR (Presentation Schema)\n   - Scenario-based LCR projections for stress testing\n   - Columns: WHAT_IF_ID, DAY_NUMBER, TOTAL_NET_CASH_OUTFLOWS, HQLA, LCR, CREATED_TIMESTAMP\n   - Links to WHAT_IF_DEFINITIONS_LOOKUP for scenario parameters\n\n3. POSITIONS (Raw Schema)\n   - Investment positions for HQLA calculation\n   - Columns: POSITION_ID, BUSINESS_UNIT_ID, SECURITY_ID, SECURITY_TYPE, POSITION_TYPE, QUANTITY, POSITION_VALUE_USD, POSITION_DATE, MATURITY_DATE\n\n4. CASH_INFLOWS (Raw Schema)\n   - Expected cash receipts\n   - Columns: INFLOW_ID, BUSINESS_UNIT_ID, COUNTERPARTY_ID, INFLOW_TYPE, INFLOW_AMOUNT_USD, MATURITY_DATE, POSITION_DATE\n\n5. CASH_OUTFLOWS (Raw Schema)\n   - Expected cash payments\n   - Columns: OUTFLOW_ID, BUSINESS_UNIT_ID, COUNTERPARTY_ID, OUTFLOW_TYPE, OUTFLOW_AMOUNT_USD, MATURITY_DATE, POSITION_DATE\n\n**REFERENCE TABLES:**\n\n6. ASSET_CLASSIFICATIONS - Basel III HQLA classifications\n7. BUSINESS_UNIT_REFERENCE - Business unit hierarchy\n8. COUNTERPARTY_DATA - Counterparty information\n9. WHAT_IF_DEFINITIONS_LOOKUP - Scenario parameters"
        }
      }
    ],
    "tool_resources": {
      "LIQUIDITY_ANALYST": {
        "execution_environment": {
          "type": "warehouse",
          "warehouse": "LIQUIDITY_RISK_AGENT_WH"
        },
        "semantic_view": "LIQUIDITY_RISK_DB.PUBLIC.LIQUIDITY_SV"
      }
    }
  }
$$;

-- Add agent to Snowflake Intelligence
USE ROLE ACCOUNTADMIN;
CREATE OR REPLACE PROCEDURE LIQUIDITY_RISK_DB.PUBLIC.ADD_LIQUIDITY_AGENT_TO_INTELLIGENCE()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
BEGIN
    BEGIN
        ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT 
          DROP AGENT LIQUIDITY_RISK_DB.PUBLIC.LIQUIDITY_FORECAST_AGENT;
    EXCEPTION
        WHEN OTHER THEN
            NULL;
    END;
    
    ALTER SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT 
      ADD AGENT LIQUIDITY_RISK_DB.PUBLIC.LIQUIDITY_FORECAST_AGENT;
    
    RETURN 'Liquidity Forecast Agent added successfully to Snowflake Intelligence';
END;
$$;
CALL LIQUIDITY_RISK_DB.PUBLIC.ADD_LIQUIDITY_AGENT_TO_INTELLIGENCE();

-- =====================================================
-- SECTION 14: Verification
-- =====================================================
SHOW NOTEBOOKS IN SCHEMA LIQUIDITY_RISK_DB.PUBLIC;
SHOW STREAMLITS IN SCHEMA LIQUIDITY_RISK_DB.PUBLIC;
SHOW SEMANTIC VIEWS IN SCHEMA LIQUIDITY_RISK_DB.PUBLIC;
SHOW AGENTS IN SCHEMA LIQUIDITY_RISK_DB.PUBLIC;

-- =====================================================
-- SECTION 15: Teardown (Uncomment to clean up)
-- =====================================================
-- DROP DATABASE IF EXISTS LIQUIDITY_RISK_DB;
-- DROP WAREHOUSE IF EXISTS LIQUIDITY_RISK_WH;
-- DROP WAREHOUSE IF EXISTS LIQUIDITY_RISK_AGENT_WH;
-- DROP ROLE IF EXISTS LIQUIDITY_RISK_ROLE;
