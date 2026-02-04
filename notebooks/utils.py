# Copyright 2026 Snowflake Inc.
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

def build_factor_query(id_column, factor_alias, source_table, match_columns, ref_tbl, tbl, what_if_id, db):
    """
    Build a factor aggregation query for what-if scenario analysis.
    
    Args:
        id_column: Primary key column (e.g., 'business_unit_id', 'counterparty_id', 'security_type')
        factor_alias: Name for the output factor column (e.g., 'bu_factor', 'cp_factor')
        source_table: Source reference table (e.g., 'RAW.BUSINESS_UNIT_REFERENCE')
        match_columns: List of columns to match with VAL (e.g., ['REGION', 'BUSINESS_UNIT_TYPE'])
        ref_tbl: Reference table name for WHAT_IF_DEFINITIONS_LOOKUP filter
        tbl: Table name for WHAT_IF_DEFINITIONS_LOOKUP filter
        what_if_id: What-if scenario ID
        db: Database name for WHAT_IF_DEFINITIONS_LOOKUP table
    
    Returns:
        SQL query string that computes aggregated factors
    """
    # Build the ON clause with OR conditions for each match column
    match_conditions = " OR ".join([f"a.{col} = b.VAL" for col in match_columns])
    
    return f"""
        SELECT 
            {id_column},
            REDUCE((ARRAY_AGG(FACTOR::NUMBER(12, 2)) WITHIN GROUP (ORDER BY FACTOR ASC)), 1, (acc, x) -> acc * x) AS {factor_alias}
        FROM (
            SELECT a.{id_column}, b.factor+1 as factor
            FROM {source_table} a
            LEFT JOIN {db}.RAW_SANDBOX.WHAT_IF_DEFINITIONS_LOOKUP b
            ON {match_conditions}
            WHERE b.WHAT_IF_ID = {what_if_id}
            AND b.REF_TBL = '{ref_tbl}' 
            AND b.TBL = '{tbl}' 
        )
        GROUP BY 1
    """

def build_merge_query(id_column, amount_usd_col, base_tbl, queries_definitions):
    """
    Build a merge query for what-if scenario analysis.
    
    Args:
        id_column: Primary key column (e.g., 'business_unit_id', 'counterparty_id', 'security_type')
        amount_usd_col: Name for the value in USD column (e.g., 'bu_factor', 'cp_factor')
        # factor_alias: Name for the output factor column (e.g., 'inflow_amount_usd', 'outflow_amount_usd', position_value_usd)
        source_table: Source reference table (e.g., 'RAW.BUSINESS_UNIT_REFERENCE')
        match_columns: List of columns to match with VAL (e.g., ['REGION', 'BUSINESS_UNIT_TYPE'])
        ref_tbl: Reference table name for WHAT_IF_DEFINITIONS_LOOKUP filter
        tbl: Table name for WHAT_IF_DEFINITIONS_LOOKUP filter
        what_if_id: What-if scenario ID
    
    Returns:
        SQL query string that computes aggregated factors
    """    
    query = f"""
        MERGE INTO {base_tbl} target
        USING (
            SELECT 
                a.{id_column},
                (a.{amount_usd_col} * COALESCE(b.{queries_definitions[0]['factor_column']}, 1) * COALESCE(c.{queries_definitions[1]['factor_column']}, 1)) AS new_{amount_usd_col}
            FROM {base_tbl} a
            LEFT JOIN ( {queries_definitions[0]['query']} ) b ON a.{queries_definitions[0]['join_column']}= b.{queries_definitions[0]['join_column']}
            LEFT JOIN ( {queries_definitions[1]['query']} ) c ON a.{queries_definitions[1]['join_column']} = c.{queries_definitions[1]['join_column']}
            order by {id_column}
        ) source
        ON target.{id_column} = source.{id_column}
        WHEN MATCHED THEN 
            UPDATE SET target.{amount_usd_col} = source.new_{amount_usd_col};
        """    
    return query    

def clone_and_update(session, what_if_args):
    
    session.sql(f"""CREATE OR REPLACE TRANSIENT TABLE {what_if_args['positions_table_clone']} CLONE {what_if_args['positions_table']}""").collect()
    session.sql(f"""CREATE OR REPLACE TRANSIENT TABLE {what_if_args['outflows_table_clone']} CLONE {what_if_args['outflows_table']}""").collect()
    session.sql(f"""CREATE OR REPLACE TRANSIENT TABLE {what_if_args['inflows_table_clone']} CLONE {what_if_args['inflows_table']}""").collect()  
    
    # Query: Business Unit factors for inflows
    inflows_factor_query = build_factor_query(
            id_column='business_unit_id',
            factor_alias='bu_factor',
            source_table=f'{what_if_args["db"]}.RAW.BUSINESS_UNIT_REFERENCE',
            match_columns=['REGION', 'BUSINESS_UNIT_TYPE'],
            ref_tbl='CASH_INFLOWS',
            tbl='BUSINESS_UNIT_REFERENCE',
            what_if_id=what_if_args['what_if_id'],
            db=what_if_args['db']
        )
    
    # Query: Business Unit factors for outflows
    outflows_factor_query = build_factor_query(
            id_column='business_unit_id',
            factor_alias='bu_factor',
            source_table=f'{what_if_args["db"]}.RAW.BUSINESS_UNIT_REFERENCE',
            match_columns=['REGION', 'BUSINESS_UNIT_TYPE'],
            ref_tbl='CASH_OUTFLOWS',
            tbl='BUSINESS_UNIT_REFERENCE',
            what_if_id=what_if_args['what_if_id'],
            db=what_if_args['db']
        )    
    
    # Query: Counterparty factors
    cp_factor_query = build_factor_query(
            id_column='counterparty_id',
            factor_alias='cp_factor',
            source_table=f'{what_if_args["db"]}.RAW.COUNTERPARTY_DATA',
            match_columns=['REGION', 'COUNTERPARTY_TYPE'],
            ref_tbl='COUNTERPARTY_DATA',
            tbl='COUNTERPARTY_DATA',
            what_if_id=what_if_args['what_if_id'],
            db=what_if_args['db']
        )    
    
    # Query: BU factors for positions
    bu_factor_query = build_factor_query(
            id_column='business_unit_id',
            factor_alias='bu_factor',
            source_table=f'{what_if_args["db"]}.RAW.BUSINESS_UNIT_REFERENCE',
            match_columns=['REGION', 'BUSINESS_UNIT_TYPE'],
            ref_tbl='POSITIONS',
            tbl='BUSINESS_UNIT_REFERENCE',
            what_if_id=what_if_args['what_if_id'],
            db=what_if_args['db']
        )    
    
    # Query: Security Type factors
    sec_type_factor_query = build_factor_query(
            id_column='security_type',
            factor_alias='sec_type_factor',
            source_table=f'{what_if_args["db"]}.RAW.ASSET_CLASSIFICATIONS',
            match_columns=['SECURITY_TYPE'],
            ref_tbl='POSITIONS',
            tbl='ASSET_CLASSIFICATIONS',
            what_if_id=what_if_args['what_if_id'],
            db=what_if_args['db']
        )    
    
    queries_definitions = [
        {'query':cp_factor_query,'join_column':'counterparty_id','factor_column':'cp_factor'},
        {'query':inflows_factor_query,'join_column':'business_unit_id','factor_column':'bu_factor'},]
    inflow_merge = build_merge_query('inflow_id', 'inflow_amount_usd', what_if_args['inflows_table_clone'], queries_definitions)
    
    session.sql(inflow_merge).collect()    
    
    queries_definitions = [
        {'query':cp_factor_query,'join_column':'counterparty_id','factor_column':'cp_factor'},
        {'query':outflows_factor_query,'join_column':'business_unit_id','factor_column':'bu_factor'},]
    outflow_merge = build_merge_query('outflow_id', 'outflow_amount_usd', what_if_args['outflows_table_clone'], queries_definitions)
    
    session.sql(outflow_merge).collect()    
    
    queries_definitions = [
        {'query':bu_factor_query,'join_column':'business_unit_id','factor_column':'bu_factor'},
        {'query':sec_type_factor_query,'join_column':'security_type','factor_column':'sec_type_factor'},]
    position_merge = build_merge_query('position_id', 'position_value_usd', what_if_args['positions_table_clone'], queries_definitions)
    
    session.sql(position_merge).collect()    