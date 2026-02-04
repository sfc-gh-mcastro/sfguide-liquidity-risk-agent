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

# Import python packages
import snowflake.snowpark as snowpark
from snowflake.snowpark import functions as F
from snowflake.snowpark.types import *
import datetime

def run_hqla_projection(session, db: str, n_days: int, input_table_name: str, output_table_name: str, decay: float = 0.99) -> str:
    """
    This is the inner logic that runs *inside* Snowflake.
    It builds the 150-day projection using the Snowpark DataFrame API.
    """
    
    # 1. Define the source table
    base_data = session.sql(f"""
        SELECT 
            tp.MATURITY_DATE,
            tp.POSITION_VALUE_USD * (1 - hc.HAIRCUT_PERCENT/100) AS TOTAL_HQLA_USD
        FROM {input_table_name} tp
        JOIN {db}.RAW.ASSET_CLASSIFICATIONS hc ON tp.SECURITY_TYPE = hc.SECURITY_TYPE
        WHERE tp.POSITION_TYPE = 'Long'
        AND (tp.MATURITY_DATE IS NULL OR tp.MATURITY_DATE >= CURRENT_DATE())
        """)

    # 2. Get current date
    current_date = datetime.datetime.now()
    
    # 3. Define the key (grouping) columns
    key_cols = base_data.columns
    
    # 4. --- This is the dynamic part ---
    # Generate the list of projection columns
    projection_cols = []
    for i in range(n_days):
        # Day 1 is offset 0, Day x is offset x-1
        day_offset = i
        
        # This is the "calculation_date" for this column
        calc_date = current_date + datetime.timedelta(days=day_offset)
        
        # Calculate decay factor: x% reduction per day (0.5 ** day_offset)

        decay_factor = decay ** day_offset
        
        # Your logic: "If MATURITY_DATE is less than calc_date, 0"
        # Otherwise apply the decay factor to the value
        stock_logic = F.when(F.col("MATURITY_DATE") <= calc_date, F.lit(0)) \
               .otherwise(F.col("TOTAL_HQLA_USD") * F.lit(decay_factor)) \
               .cast(DecimalType(38, 2))  
        
        # Add this new expression to our list with a clear alias
        projection_cols.append(
            stock_logic.alias(f"DAY_{i+1}_TOTAL_HQLA_USD")
        )
    
    # 5. Build the final DataFrame
    # Select all the key columns and "unpack" the x new projection columns
    final_df = base_data.select(*key_cols, *projection_cols)
    
    # 6. Save the results to the specified output table
    final_df.write.mode("overwrite").save_as_table(output_table_name, table_type="transient")
    
    return f"Successfully created {n_days}-day projection in {output_table_name}."


def run_summary_hqla(session, n_days: int,
                input_table: str, 
                output_table_name: str) -> str:
    """
    This is the inner logic that runs *inside* Snowflake.
    It unpivots, aggregates, and nets the two projection tables.
    """
    
    # --- 1. Define Column Lists ---
    cols = [f"DAY_{i+1}_TOTAL_HQLA_USD" for i in range(n_days)]
    
    # --- 2. Process Inflows ---
    input_df = session.table(input_table)
    unpivoted_input = input_df.unpivot("AMOUNT", "DAY_RAW", cols)
    
    # Clean the DAY_RAW string and aggregate
    agg_input = unpivoted_input.group_by(
        # Extract the first group of digits (\d+) found in the string.
        F.regexp_extract(F.col("DAY_RAW"), F.lit("(\\d+)"), 1).cast(IntegerType()).alias("DAY_NUMBER")
    ).agg(
        F.sum("AMOUNT").alias("TOTAL_HQLA_USD")
    )
    
    final_df = agg_input.select(
        F.col("DAY_NUMBER"),
        F.coalesce(F.col("TOTAL_HQLA_USD"), F.lit(0)).alias("TOTAL_HQLA_USD"),
    ).order_by("DAY_NUMBER")
    
    # --- 5. Save the Final Report ---
    final_df.write.mode("overwrite").save_as_table(output_table_name, table_type="transient")
    
    return f"Successfully created Total HQLA report in {output_table_name}."


def run_cashflow_projection(session, direction: str, n_days: int, input_table_name: str, output_table_name: str) -> str:
    """
    This is the inner logic that runs *inside* Snowflake.
    It builds the 150-day projection using the Snowpark DataFrame API.
    """
    
    # 1. Define the source table
    base_df = session.table(input_table_name)
    
    # 2. Get the most recent POSITION_DATE to work with
    current_date = datetime.datetime.now()
    
    base_data = base_df.filter(
        (F.col("MATURITY_DATE") >= current_date)
        |
        (F.col("MATURITY_DATE").is_null())
    )
    
    # 3. Define the key (grouping) columns
    key_cols = base_df.columns
    
    # 4. --- This is the dynamic part ---
    # Generate the list of projection columns
    projection_cols = []
    for i in range(n_days):
        # Day 1 is offset 0, Day x is offset x-1
        day_offset = i
        
        # This is the "calculation_date" for this column
        # calc_date = datetime.dateadd("day", F.lit(day_offset), current_date)
        calc_date = current_date + datetime.timedelta(days=day_offset)
        
        # Your logic: "If MATURITY_DATE is less than calc_date, 0"
        stock_logic = F.when(F.col("MATURITY_DATE") < calc_date, F.lit(0)) \
                       .otherwise(F.col(f"{direction}_AMOUNT_USD"))
        
        # Add this new expression to our list with a clear alias
        projection_cols.append(
            stock_logic.alias(f"DAY_{i+1}_{direction}_STOCK")
        )
    
    # 5. Build the final DataFrame
    # Select all the key columns and "unpack" the x new projection columns
    final_df = base_data.select(*key_cols, *projection_cols)
    
    # 6. Save the results to the specified output table
    final_df.write.mode("overwrite").save_as_table(output_table_name, table_type="transient")
    
    return f"Successfully created {n_days}-day projection in {output_table_name}."


def run_netting(session, n_days: int,
                inflow_table: str, 
                outflow_table: str, 
                output_table_name: str) -> str:
    """
    This is the inner logic that runs *inside* Snowflake.
    It unpivots, aggregates, and nets the two projection tables.
    """
    
    # --- 1. Define Column Lists ---
    inflow_cols = [f"DAY_{i+1}_INFLOW_STOCK" for i in range(n_days)]
    outflow_cols = [f"DAY_{i+1}_OUTFLOW_STOCK" for i in range(n_days)]
    
    # --- 2. Process Inflows ---
    inflow_df = session.table(inflow_table)
    unpivoted_inflows = inflow_df.unpivot("AMOUNT", "DAY_RAW", inflow_cols)
    
    # Clean the DAY_RAW string and aggregate
    agg_inflows = unpivoted_inflows.group_by(
        # Extract the first group of digits (\d+) found in the string.
        F.regexp_extract(F.col("DAY_RAW"), F.lit("(\\d+)"), 1).cast(IntegerType()).alias("DAY_NUMBER")
    ).agg(
        F.sum("AMOUNT").alias("TOTAL_INFLOW")
    )

    # --- 3. Process Outflows ---
    outflow_df = session.table(outflow_table)
    unpivoted_outflows = outflow_df.unpivot("AMOUNT", "DAY_RAW", outflow_cols)
    
    # Clean the DAY_RAW string and aggregate
    agg_outflows = unpivoted_outflows.group_by(
        # Use the same simple regex to extract the first group of digits.
        F.regexp_extract(F.col("DAY_RAW"), F.lit("(\\d+)"), 1).cast(IntegerType()).alias("DAY_NUMBER")
    ).agg(
        F.sum("AMOUNT").alias("TOTAL_OUTFLOW")
    )

    # --- 4. Join and Calculate Net Position ---
    net_df = agg_inflows.join(
        agg_outflows,
        ["DAY_NUMBER"],
        "full"
    )
    
    final_df = net_df.select(
        F.col("DAY_NUMBER"),
        F.coalesce(F.col("TOTAL_INFLOW"), F.lit(0)).alias("TOTAL_INFLOW"),
        F.coalesce(F.col("TOTAL_OUTFLOW"), F.lit(0)).alias("TOTAL_OUTFLOW"),
        (
            F.coalesce(F.col("TOTAL_INFLOW"), F.lit(0)) + 
            F.coalesce(F.col("TOTAL_OUTFLOW"), F.lit(0))
        ).alias("NET_POSITION"),
        F.abs(
            F.coalesce(F.col("TOTAL_INFLOW"), F.lit(0)) + 
            F.coalesce(F.col("TOTAL_OUTFLOW"), F.lit(0))
        ).alias("ABS_NET_POSITION")
    ).order_by("DAY_NUMBER")
    
    # --- 5. Save the Final Report ---
    final_df.write.mode("overwrite").save_as_table(output_table_name, table_type="transient")
    
    return f"Successfully created net position report in {output_table_name}."
    