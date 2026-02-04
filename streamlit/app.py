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

"""
Liquidity Coverage Ratio Dashboard - Streamlit in Snowflake Application
Shows LCR metrics and What-if scenario analysis
"""

import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import random
import string

from snowflake.snowpark.context import get_active_session
from snowflake.snowpark.functions import col, sum as sum_func


# Page config
st.set_page_config(
    page_title="Liquidity Coverage Ratio Dashboard",
    page_icon="💰",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Get Snowflake session
try:
    session = get_active_session()
except Exception as e:
    st.error(f"Failed to connect to Snowflake: {str(e)}")
    st.stop()

db = "LIQUIDITY_RISK_DB"

# Sidebar navigation
page = st.sidebar.selectbox(
    "Select Page",
    ["LCR Dashboard", "What-if Scenarios Complex", "Ask the Agent"]
)

# LCR Dashboard Page
if page == "LCR Dashboard":
    st.header("💰 Liquidity Coverage Ratio Dashboard")
    st.markdown("Real-time LCR metrics and trends")

    # Load LCR data
    latest_calc_ts = session.sql(f"select max(created_timestamp) from {db}.PRESENTATION.LCR")

    lcr_data = session.sql(f"""
    SELECT *
    FROM {db}.PRESENTATION.LCR 
    WHERE created_timestamp IN (SELECT max(created_timestamp) FROM {db}.PRESENTATION.LCR)
    ORDER BY day_number""").to_pandas()
    
    if not lcr_data.empty:
        # High-level metrics for today (DAY_NUMBER = 1)
        today_data = lcr_data[lcr_data["DAY_NUMBER"] == 1].iloc[0] if len(lcr_data[lcr_data["DAY_NUMBER"] == 1]) > 0 else None
        
        if today_data is not None:
            st.subheader("📊 Today's Metrics (Day 1)")
            col1, col2, col3 = st.columns(3)
            
            with col1:
                st.metric(
                    "LCR",
                    f"{today_data['LCR']:,.2f}",
                    delta="Compliant" if today_data['LCR'] >= 1.0 else "Non-Compliant"
                )
            
            with col2:
                st.metric(
                    "HQLA",
                    f"${today_data['HQLA']:,.0f}"
                )
            
            with col3:
                st.metric(
                    "Total Net Cash Outflows For Next 30 Days",
                    f"${today_data['TOTAL_NET_CASH_OUTFLOWS']:,.0f}"
                )
        
        # Line chart: Day_Number vs LCR
        st.subheader("📈 LCR Trend Over Time")

        fig = px.line(
            lcr_data,
            x="DAY_NUMBER",
            y="LCR",
            title="Liquidity Coverage Ratio Over Time",
            labels={
                "DAY_NUMBER": "Day Number",
                "LCR": "LCR Ratio"
            },
            markers=True
        )        
        
        # Add compliance threshold line at 1.0
        fig.add_hline(
            y=1.0,
            line_dash="dash",
            line_color="red",
            annotation_text="Minimum Compliance (1.0)"
        )
        
        # Update layout
        fig.update_layout(
            height=500,
            hovermode='x unified',
            xaxis_title="Day Number",
            yaxis_title="LCR Ratio",
            showlegend=False
        )
        
        st.plotly_chart(fig, use_container_width=True)
        
        # Show data table
        with st.expander("📋 View Raw Data", expanded=False):
            lcr_data['TOTAL_NET_CASH_OUTFLOWS'] = lcr_data.apply(lambda x: "${:,.0f}".format(x['TOTAL_NET_CASH_OUTFLOWS']), axis=1)

            lcr_data['HQLA'] = lcr_data.apply(lambda x: "${:,.0f}".format(x['HQLA']), axis=1)

            st.dataframe(lcr_data, use_container_width=True)


    
    else:
        st.warning("No LCR data available. Please ensure the LCR table is populated.")

    if st.button("🚀 Re-Calculate LCR", type="primary", use_container_width=True):
        with st.spinner("Executing LCR Calculations..."):    
            try:
                start_time = pd.Timestamp.now()
            
                # Build the EXECUTE NOTEBOOK statement
                # Note: EXECUTE NOTEBOOK requires proper SQL syntax
                notebook_call = (
                    f"EXECUTE NOTEBOOK {db}.PUBLIC.LIQUIDITY_FORECAST("
                    f"'db={db}', "
                    f"'positions_table={db}.raw.POSITIONS', "
                    f"'inflows_table={db}.raw.CASH_INFLOWS', "
                    f"'outflows_table={db}.raw.CASH_OUTFLOWS' "
                    f")"
                )
                # Execute the notebook
                result = session.sql(notebook_call).collect()
    
                end_time = pd.Timestamp.now()
                elapsed = (end_time - start_time).total_seconds()
                
                st.rerun()
                
            except Exception as e:
                st.error(f"❌ Error executing LCR Calculations: {str(e)}")
                st.info("Please verify that:")
                st.info(f"1. The notebook {db}.PUBLIC.LIQUIDITY_FORECAST exists")
                st.info("2. You have EXECUTE NOTEBOOK privileges")
                st.info("3. All required tables exist")
    # except Exception as e:
    #     st.error(f"❌ Error loading LCR data: {str(e)}")
    #     st.info(f"Please verify that the table {db}.PRESENTATION.LCR exists and contains data.")


elif page == "What-if Scenarios Complex":
    st.header("🔮 What-if Scenario Analysis")
    st.markdown("Run Pre-Defined what-if scenarios to analyze impact of adjustments on LCR")
    
    try:
        # Load business units from POSITIONS table
        
        what_if_ids_df = session.table(f"{db}.RAW.WHAT_IF_DEFINITIONS_LOOKUP")\
            .select("WHAT_IF_ID", "WHAT_IF_NAME", "REF_TBL", "COL", "VAL", "FACTOR")\
            .distinct()\
            .order_by("WHAT_IF_ID", "REF_TBL", "COL")\
            .to_pandas()
        
        what_if_ids = set(what_if_ids_df["WHAT_IF_ID"].tolist())
        
        if not what_if_ids:
            st.warning("No What-If IDs found in WHAT_IF_DEFINITIONS_LOOKUP table.")
        else:
            # What If ID dropdown
            what_if_id = st.selectbox(
                "Select What-If ID",
                options=list(what_if_ids),
                help="Select the What-If ID for the what-if scenario calculation"
            )   

            # Data table
            with st.expander("📋 View What-if Definition", expanded=False):
                filtered_df = what_if_ids_df[what_if_ids_df['WHAT_IF_ID'] == f'{what_if_id}']
                st.dataframe(filtered_df, use_container_width=True)
                
            # Execute Notebook button
            if st.button("🚀 Execute Pre-Defined What-if Scenario", type="primary", use_container_width=True):
                with st.spinner("Executing what-if scenario notebook..."):
                    try:

                        start_time = pd.Timestamp.now()

                        suffix_length = 8
                        random_string = ''.join(random.choices(string.ascii_letters + string.digits, k=suffix_length))
                    
                        # Build the EXECUTE NOTEBOOK statement
                        # Note: EXECUTE NOTEBOOK requires proper SQL syntax
                        notebook_call = (
                            # f"EXECUTE NOTEBOOK {db}.PUBLIC.LIQUIDITY_WHAT_IF("
                            f"EXECUTE NOTEBOOK {db}.PUBLIC.LIQUIDITY_WHAT_IF_FORECAST_SANDBOX("
                            f"'db={db}', "
                            f"'positions_table={db}.RAW_SANDBOX.POSITIONS', "
                            f"'inflows_table={db}.RAW_SANDBOX.CASH_INFLOWS', "
                            f"'outflows_table={db}.RAW_SANDBOX.CASH_OUTFLOWS', "
                            f"'suffix={random_string}',"
                            f"'what_if_id={what_if_id}'"
                            f")"
                        )
                        # Execute the notebook
                        result = session.sql(notebook_call).collect()

                        end_time = pd.Timestamp.now()
                        elapsed = (end_time - start_time).total_seconds()
                    
                        st.success("✅ What-if scenario executed successfully!")
                        st.info(f"⏱️ Data refreshed in {elapsed:.2f} seconds")
                        
                        # Try to load and display results from lcr_what_if table
                        try:
                            
                            what_if_results = session.sql(f"""
                            SELECT *
                            FROM {db}.PRESENTATION.WHAT_IF_LCR 
                            WHERE what_if_id = {what_if_id}
                            AND created_timestamp IN (SELECT max(created_timestamp) 
                                                      FROM {db}.PRESENTATION.WHAT_IF_LCR 
                                                      WHERE what_if_id = {what_if_id})
                            ORDER BY day_number""").to_pandas()
    
                            # what_if_results = session.table(f"{db}.PRESENTATION.WHAT_IF_LCR")\
                            #     .order_by("DAY_NUMBER")\
                            #     .to_pandas()
                            
                            if not what_if_results.empty:
                                st.subheader("📊 What-if Scenario Results")
                                
                                # Metrics for Day 1
                                if len(what_if_results[what_if_results["DAY_NUMBER"] == 1]) > 0:
                                    day1_data = what_if_results[what_if_results["DAY_NUMBER"] == 1].iloc[0]
                                    
                                    col1, col2, col3 = st.columns(3)
                                    with col1:
                                        st.metric("LCR", f"{day1_data.get('LCR', 'N/A'):,.4f}" if 'LCR' in day1_data else "N/A")
                                    with col2:
                                        st.metric("HQLA", f"${day1_data.get('HQLA', 'N/A'):,.2f}" if 'HQLA' in day1_data else "N/A")
                                    with col3:
                                        st.metric("Total Net Cash Outflows For Next 30 Days", 
                                                f"${day1_data.get('TOTAL_NET_CASH_OUTFLOWS', 'N/A'):,.2f}" 
                                                if 'TOTAL_NET_CASH_OUTFLOWS' in day1_data else "N/A")
                                
                                # Chart comparing what-if vs baseline
                                if 'LCR' in what_if_results.columns:
                                    fig = px.line(
                                        what_if_results,
                                        x="DAY_NUMBER",
                                        y="LCR",
                                        title=f"What-if Scenario: {what_if_id}",
                                        labels={
                                            "DAY_NUMBER": "Day Number",
                                            "LCR": "LCR Ratio"
                                        },
                                        markers=True
                                    )
                                    
                                    fig.add_hline(
                                        y=1.0,
                                        line_dash="dash",
                                        line_color="red",
                                        annotation_text="Minimum Compliance (1.0)"
                                    )
                                    
                                    fig.update_layout(height=500)
                                    st.plotly_chart(fig, use_container_width=True)
                                
                                # Data table
                                with st.expander("📋 View What-if Results Data", expanded=False):

                                    what_if_results['TOTAL_NET_CASH_OUTFLOWS'] = what_if_results.apply(lambda x: "${:,.0f}".format(x['TOTAL_NET_CASH_OUTFLOWS']), axis=1)
                                    what_if_results['HQLA'] = what_if_results.apply(lambda x: "${:,.0f}".format(x['HQLA']), axis=1)
                        
                                    st.dataframe(what_if_results, use_container_width=True)

                            else:
                                st.info("What-if scenario executed, but no results found in WHAT_IF_LCR table.")
                        except Exception as e:
                            st.warning(f"Could not load what-if results: {str(e)}")
                            st.info("The notebook executed successfully, but results may not be available yet.")
                    
                    except Exception as e:
                        st.error(f"❌ Error executing what-if scenario: {str(e)}")
                        st.info("Please verify that:")
                        st.info(f"1. The notebook {db}.PUBLIC.LIQUIDITY_WHAT_IF_FORECAST_SANDBOX exists")
                        st.info("2. You have EXECUTE NOTEBOOK privileges")
                        st.info("3. All required tables exist")
    
    except Exception as e:
        st.error(f"❌ Error loading What-if IDs: {str(e)}, {Exception}")
        # st.info(f"Please verify that the table {db}.RAW.POSITIONS exists and contains data.")

elif page == "Ask the Agent":
    st.header("🤖 Ask the Liquidity Forecast Agent")
    st.markdown("Ask natural language questions about liquidity positions, LCR forecasts, HQLA composition, and more.")
    
    # Initialize session state for chat history and conversation ID
    if "agent_messages" not in st.session_state:
        st.session_state.agent_messages = []
    if "agent_conversation_id" not in st.session_state:
        st.session_state.agent_conversation_id = ''.join(random.choices(string.ascii_letters + string.digits, k=16))
    
    # Sample questions as clickable buttons
    sample_questions = [
        "What's LCR today and headroom vs floor?",
        "Why did LCR move? What are top 3 causes?",
        "7/30 days - where's LCR heading?",
        "Intraday alerts: Any surprises now?",
        "DQ - is our data reliable today? Recon status? Any missing fields?",
        "Governance & overrides - who approved changes?"
    ]
    
    # Initialize pending question in session state
    if "pending_question" not in st.session_state:
        st.session_state.pending_question = None
    
    with st.expander("💡 Sample Questions", expanded=False):
        for q in sample_questions:
            if st.button(q, key=f"sample_{q}", use_container_width=True):
                st.session_state.pending_question = q
                st.rerun()
    
    # Clear chat button
    if st.button("🗑️ Clear Chat", use_container_width=False):
        st.session_state.agent_messages = []
        st.session_state.agent_conversation_id = ''.join(random.choices(string.ascii_letters + string.digits, k=16))
        st.rerun()
    
    # Display chat history
    for message in st.session_state.agent_messages:
        with st.chat_message(message["role"]):
            st.markdown(message["content"])
    
    # Chat input - check for pending question from sample buttons
    user_input = st.chat_input("Ask a question about liquidity...")
    
    # Use pending question if set
    if st.session_state.pending_question:
        user_input = st.session_state.pending_question
        st.session_state.pending_question = None
    
    if user_input:
        # Add user message to chat history
        st.session_state.agent_messages.append({"role": "user", "content": user_input})
        
        # Display user message
        with st.chat_message("user"):
            st.markdown(user_input)
        
        # Get response from Cortex Analyst
        with st.chat_message("assistant"):
            with st.spinner("Thinking..."):
                try:
                    import _snowflake
                    import json
                    
                    # Use Cortex Analyst directly with the semantic view
                    # This queries the LIQUIDITY_SV semantic view for LCR data
                    semantic_view = f"{db}.PUBLIC.LIQUIDITY_SV"
                    
                    # Build the request payload for Cortex Analyst API
                    payload = {
                        "semantic_view": semantic_view,
                        "messages": [
                            {
                                "role": "user", 
                                "content": [
                                    {"type": "text", "text": user_input}
                                ]
                            }
                        ]
                    }
                    
                    # Use _snowflake.send_snow_api_request for internal API calls
                    response = _snowflake.send_snow_api_request(
                        "POST",
                        "/api/v2/cortex/analyst/message",
                        {},  # headers
                        {},  # params  
                        payload,  # body as dict
                        {},  # request_guid
                        120000  # timeout in ms
                    )
                    
                    # Parse the response from Cortex Analyst
                    if response:
                        # Response might be a string, dict, or have nested content
                        if isinstance(response, str):
                            try:
                                result = json.loads(response)
                            except json.JSONDecodeError:
                                result = {"raw": response}
                        elif isinstance(response, dict):
                            # Check if there's a 'content' wrapper (API response format)
                            if 'content' in response and isinstance(response['content'], str):
                                try:
                                    result = json.loads(response['content'])
                                except json.JSONDecodeError:
                                    result = response
                            else:
                                result = response
                        else:
                            result = {"raw": str(response)}
                        
                        # Check for error in response
                        if isinstance(result, dict) and 'status' in result and result.get('status') >= 400:
                            error_content = result.get('content', str(result))
                            raise Exception(f"API Error: {error_content}")
                        
                        # Handle response formats
                        agent_response = None
                        sql_query = None
                        
                        if isinstance(result, list):
                            # Streaming response format (array of events)
                            for event in result:
                                if isinstance(event, dict):
                                    event_type = event.get('event', '')
                                    if event_type == 'response.text':
                                        data = event.get('data', {})
                                        if isinstance(data, dict):
                                            agent_response = data.get('text', '')
                                            break
                            
                            if not agent_response:
                                text_parts = []
                                for event in result:
                                    if isinstance(event, dict):
                                        event_type = event.get('event', '')
                                        if event_type == 'response.text.delta':
                                            data = event.get('data', {})
                                            if isinstance(data, dict):
                                                text_parts.append(data.get('text', ''))
                                agent_response = ''.join(text_parts)
                        
                        elif isinstance(result, dict) and 'message' in result:
                            # Cortex Analyst response format - handle this FIRST
                            message = result['message']
                            if isinstance(message, dict):
                                content = message.get('content', [])
                                response_parts = []
                                
                                for item in content:
                                    if isinstance(item, dict):
                                        if item.get('type') == 'text':
                                            response_parts.append(item.get('text', ''))
                                        elif item.get('type') == 'sql':
                                            sql_query = item.get('statement', '')
                                
                                # Display the interpretation text
                                if response_parts:
                                    st.markdown('\n'.join(response_parts))
                                
                                # Execute the SQL and display results
                                if sql_query:
                                    sql_query = sql_query.replace('≤', '<=').replace('≥', '>=')
                                    sql_query = sql_query.replace('—', '--')
                                    
                                    with st.expander("📝 Generated SQL", expanded=False):
                                        st.code(sql_query, language='sql')
                                    
                                    try:
                                        query_result = session.sql(sql_query).to_pandas()
                                        
                                        if not query_result.empty:
                                            # Smart chart detection based on columns
                                            cols = [c.upper() for c in query_result.columns]
                                            chart_created = False
                                            
                                            # LCR Trend over time (line chart)
                                            if 'DAY_NUMBER' in cols and 'LCR' in cols:
                                                st.subheader("📈 LCR Forecast Trend")
                                                fig = px.line(
                                                    query_result,
                                                    x="DAY_NUMBER",
                                                    y="LCR",
                                                    title="Liquidity Coverage Ratio Over Time",
                                                    labels={"DAY_NUMBER": "Day Number", "LCR": "LCR Ratio"},
                                                    markers=True
                                                )
                                                fig.add_hline(y=1.0, line_dash="dash", line_color="red", 
                                                            annotation_text="Minimum Compliance (1.0)")
                                                fig.update_layout(height=400)
                                                st.plotly_chart(fig, use_container_width=True)
                                                chart_created = True
                                            
                                            # HQLA by Level (pie/bar chart)
                                            elif 'HQLA_LEVEL' in cols and any(c in cols for c in ['TOTAL_VALUE', 'POSITION_VALUE_USD', 'AMOUNT', 'SUM', 'COUNT']):
                                                value_col = next((c for c in ['TOTAL_VALUE', 'POSITION_VALUE_USD', 'AMOUNT', 'SUM', 'COUNT'] if c in cols), None)
                                                if value_col:
                                                    st.subheader("📊 HQLA Composition by Level")
                                                    fig = px.pie(query_result, names='HQLA_LEVEL', values=value_col,
                                                                title="High-Quality Liquid Assets by Level")
                                                    st.plotly_chart(fig, use_container_width=True)
                                                    chart_created = True
                                            
                                            # Business Unit breakdown (bar chart)
                                            elif any(c in cols for c in ['BUSINESS_UNIT_ID', 'BUSINESS_UNIT_NAME', 'BUSINESS_UNIT']):
                                                bu_col = next((c for c in ['BUSINESS_UNIT_NAME', 'BUSINESS_UNIT_ID', 'BUSINESS_UNIT'] if c in cols), None)
                                                value_cols = [c for c in cols if any(v in c for v in ['AMOUNT', 'VALUE', 'TOTAL', 'SUM', 'USD', 'HQLA', 'LCR'])]
                                                if bu_col and value_cols:
                                                    st.subheader("📊 Breakdown by Business Unit")
                                                    fig = px.bar(query_result, x=bu_col, y=value_cols[0],
                                                                title=f"{value_cols[0]} by Business Unit")
                                                    fig.update_layout(height=400)
                                                    st.plotly_chart(fig, use_container_width=True)
                                                    chart_created = True
                                            
                                            # Security Type breakdown (bar chart)
                                            elif 'SECURITY_TYPE' in cols:
                                                value_cols = [c for c in cols if any(v in c for v in ['AMOUNT', 'VALUE', 'TOTAL', 'SUM', 'USD', 'COUNT'])]
                                                if value_cols:
                                                    st.subheader("📊 Breakdown by Security Type")
                                                    fig = px.bar(query_result, x='SECURITY_TYPE', y=value_cols[0],
                                                                title=f"{value_cols[0]} by Security Type")
                                                    fig.update_xaxes(tickangle=45)
                                                    fig.update_layout(height=400)
                                                    st.plotly_chart(fig, use_container_width=True)
                                                    chart_created = True
                                            
                                            # Region breakdown (bar chart)
                                            elif 'REGION' in cols:
                                                value_cols = [c for c in cols if any(v in c for v in ['AMOUNT', 'VALUE', 'TOTAL', 'SUM', 'USD', 'COUNT'])]
                                                if value_cols:
                                                    st.subheader("📊 Breakdown by Region")
                                                    fig = px.bar(query_result, x='REGION', y=value_cols[0],
                                                                title=f"{value_cols[0]} by Region")
                                                    fig.update_layout(height=400)
                                                    st.plotly_chart(fig, use_container_width=True)
                                                    chart_created = True
                                            
                                            # Counterparty Type breakdown
                                            elif 'COUNTERPARTY_TYPE' in cols:
                                                value_cols = [c for c in cols if any(v in c for v in ['AMOUNT', 'VALUE', 'TOTAL', 'SUM', 'USD', 'COUNT'])]
                                                if value_cols:
                                                    st.subheader("📊 Breakdown by Counterparty Type")
                                                    fig = px.pie(query_result, names='COUNTERPARTY_TYPE', values=value_cols[0],
                                                                title=f"{value_cols[0]} by Counterparty Type")
                                                    st.plotly_chart(fig, use_container_width=True)
                                                    chart_created = True
                                            
                                            # What-If Scenario comparison
                                            elif 'WHAT_IF_ID' in cols and 'LCR' in cols:
                                                if 'DAY_NUMBER' in cols:
                                                    st.subheader("📈 What-If Scenario Comparison")
                                                    fig = px.line(query_result, x='DAY_NUMBER', y='LCR', 
                                                                color='WHAT_IF_ID',
                                                                title="LCR by Scenario Over Time",
                                                                markers=True)
                                                    fig.add_hline(y=1.0, line_dash="dash", line_color="red",
                                                                annotation_text="Minimum Compliance (1.0)")
                                                    fig.update_layout(height=400)
                                                    st.plotly_chart(fig, use_container_width=True)
                                                    chart_created = True
                                            
                                            # Scenario comparison (baseline vs what-if with SCENARIO column)
                                            elif any(c in cols for c in ['SCENARIO', 'SCENARIO_NAME', 'SCENARIO_TYPE', 'SOURCE']) and 'LCR' in cols:
                                                scenario_col = next((c for c in ['SCENARIO', 'SCENARIO_NAME', 'SCENARIO_TYPE', 'SOURCE'] if c in cols), None)
                                                if 'DAY_NUMBER' in cols:
                                                    st.subheader("📈 Scenario Comparison")
                                                    fig = px.line(query_result, x='DAY_NUMBER', y='LCR',
                                                                color=scenario_col,
                                                                title="LCR Comparison: Baseline vs Scenario",
                                                                markers=True)
                                                    fig.add_hline(y=1.0, line_dash="dash", line_color="red",
                                                                annotation_text="Minimum Compliance (1.0)")
                                                    fig.update_layout(height=400)
                                                    st.plotly_chart(fig, use_container_width=True)
                                                    chart_created = True
                                                else:
                                                    st.subheader("📊 Scenario Comparison")
                                                    fig = px.bar(query_result, x=scenario_col, y='LCR',
                                                                title="LCR by Scenario", color=scenario_col)
                                                    fig.add_hline(y=1.0, line_dash="dash", line_color="red",
                                                                annotation_text="Minimum Compliance (1.0)")
                                                    fig.update_layout(height=400)
                                                    st.plotly_chart(fig, use_container_width=True)
                                                    chart_created = True
                                            
                                            # Generic time series (if DATE column exists)
                                            elif any('DATE' in c for c in cols):
                                                date_col = next((c for c in cols if 'DATE' in c), None)
                                                numeric_cols = query_result.select_dtypes(include=['number']).columns.tolist()
                                                if date_col and numeric_cols:
                                                    st.subheader("📈 Trend Over Time")
                                                    fig = px.line(query_result, x=date_col, y=numeric_cols[0],
                                                                title=f"{numeric_cols[0]} Over Time", markers=True)
                                                    fig.update_layout(height=400)
                                                    st.plotly_chart(fig, use_container_width=True)
                                                    chart_created = True
                                            
                                            # Multiple LCR columns (e.g., BASELINE_LCR, WHAT_IF_LCR)
                                            elif len([c for c in cols if 'LCR' in c]) > 1:
                                                lcr_cols = [c for c in cols if 'LCR' in c]
                                                x_col = 'DAY_NUMBER' if 'DAY_NUMBER' in cols else query_result.columns[0]
                                                st.subheader("📈 LCR Comparison")
                                                fig = go.Figure()
                                                for lcr_col in lcr_cols:
                                                    fig.add_trace(go.Scatter(
                                                        x=query_result[x_col], 
                                                        y=query_result[lcr_col],
                                                        mode='lines+markers',
                                                        name=lcr_col.replace('_', ' ').title()
                                                    ))
                                                fig.add_hline(y=1.0, line_dash="dash", line_color="red",
                                                            annotation_text="Minimum Compliance (1.0)")
                                                fig.update_layout(height=400, title="LCR Comparison",
                                                                xaxis_title=x_col, yaxis_title="LCR Ratio")
                                                st.plotly_chart(fig, use_container_width=True)
                                                chart_created = True
                                            
                                            # Fallback: if DAY_NUMBER exists with any numeric column
                                            elif 'DAY_NUMBER' in cols:
                                                numeric_cols = query_result.select_dtypes(include=['number']).columns.tolist()
                                                numeric_cols = [c for c in numeric_cols if c != 'DAY_NUMBER']
                                                if numeric_cols:
                                                    st.subheader("📈 Trend by Day")
                                                    if len(numeric_cols) == 1:
                                                        fig = px.line(query_result, x='DAY_NUMBER', y=numeric_cols[0],
                                                                    title=f"{numeric_cols[0]} Over Time", markers=True)
                                                    else:
                                                        fig = px.line(query_result, x='DAY_NUMBER', y=numeric_cols,
                                                                    title="Metrics Over Time", markers=True)
                                                    fig.update_layout(height=400)
                                                    st.plotly_chart(fig, use_container_width=True)
                                                    chart_created = True
                                            
                                            # Ultimate fallback: bar chart for categorical + numeric
                                            if not chart_created:
                                                categorical_cols = query_result.select_dtypes(include=['object']).columns.tolist()
                                                numeric_cols = query_result.select_dtypes(include=['number']).columns.tolist()
                                                if categorical_cols and numeric_cols and len(query_result) <= 50:
                                                    st.subheader("📊 Data Visualization")
                                                    fig = px.bar(query_result, x=categorical_cols[0], y=numeric_cols[0],
                                                                title=f"{numeric_cols[0]} by {categorical_cols[0]}")
                                                    fig.update_layout(height=400)
                                                    fig.update_xaxes(tickangle=45)
                                                    st.plotly_chart(fig, use_container_width=True)
                                                    chart_created = True
                                            
                                            # Show data table
                                            with st.expander("📋 View Data", expanded=not chart_created):
                                                st.dataframe(query_result, use_container_width=True)
                                            
                                            agent_response = f"Found {len(query_result)} rows of data."
                                        else:
                                            agent_response = "Query executed but returned no results."
                                    except Exception as sql_error:
                                        st.error(f"Error executing SQL: {str(sql_error)}")
                                        agent_response = f"SQL execution failed: {str(sql_error)}"
                                else:
                                    agent_response = '\n'.join(response_parts) if response_parts else "Response received."
                            else:
                                agent_response = str(message)
                        
                        elif isinstance(result, dict):
                            # Other dict formats
                            if 'choices' in result and len(result['choices']) > 0:
                                agent_response = result['choices'][0].get('message', {}).get('content', '')
                            elif 'response' in result:
                                agent_response = result['response']
                            elif 'text' in result:
                                agent_response = result['text']
                            else:
                                agent_response = json.dumps(result, indent=2)
                        else:
                            agent_response = str(result)
                        
                        if agent_response:
                            st.markdown(agent_response)
                            st.session_state.agent_messages.append({"role": "assistant", "content": agent_response})
                        else:
                            error_msg = "No response received from the agent."
                            st.warning(error_msg)
                            st.session_state.agent_messages.append({"role": "assistant", "content": error_msg})
                    else:
                        error_msg = "Empty response from the agent API."
                        st.warning(error_msg)
                        st.session_state.agent_messages.append({"role": "assistant", "content": error_msg})
                        
                except Exception as e:
                    error_msg = f"Error communicating with Cortex Analyst: {str(e)}"
                    st.error(error_msg)
                    st.info("Please verify that:")
                    st.info(f"1. The semantic view {db}.PUBLIC.LIQUIDITY_SV exists")
                    st.info("2. You have permissions to query the semantic view")
                    st.info("3. The underlying tables have data")
                    st.session_state.agent_messages.append({"role": "assistant", "content": error_msg})