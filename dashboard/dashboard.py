"""
Serverless Analytics Dashboard - Streamlit
Monitor your AWS Analytics API in real-time
"""

import streamlit as st
import requests
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from datetime import datetime, timedelta
import time

# Page config
st.set_page_config(
    page_title="Analytics Dashboard",
    page_icon="📊",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS
st.markdown("""
    <style>
    .metric-card {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        padding: 20px;
        border-radius: 10px;
        color: white;
    }
    .stMetric {
        background-color: #1e1e1e;
        padding: 15px;
        border-radius: 8px;
    }
    </style>
""", unsafe_allow_html=True)

# Session state for API endpoint
if 'api_endpoint' not in st.session_state:
    st.session_state.api_endpoint = ""

# Sidebar
with st.sidebar:
    st.title("⚙️ Configuration")
    
    # API Endpoint input
    api_endpoint = st.text_input(
        "API Gateway Endpoint",
        value = "https://tl22hztl73.execute-api.us-east-2.amazonaws.com/prod",
        # value=st.session_state.api_endpoint,
        placeholder="https://tl22hztl73.execute-api.us-east-2.amazonaws.com/prod",
        help="Enter your API Gateway endpoint from CloudFormation outputs"
    )
    
    if api_endpoint != st.session_state.api_endpoint:
        st.session_state.api_endpoint = api_endpoint
    
    st.divider()
    
    # Period selection
    period = st.selectbox(
        "📅 Time Period",
        options=["24h", "7d", "30d"],
        index=0,
        help="Select time range for analytics"
    )
    
    # Auto-refresh
    auto_refresh = st.checkbox("🔄 Auto-refresh (30s)", value=False)
    
    st.divider()
    
    # Manual refresh button
    if st.button("🔄 Refresh Data", use_container_width=True):
        st.rerun()
    
    st.divider()
    
    # Test section
    st.subheader("🧪 Send Test Event")
    test_page = st.text_input("Page", value="/home", key="test_page")
    test_action = st.text_input("Action", value="view", key="test_action")
    
    if st.button("📤 Send Event", use_container_width=True):
        if st.session_state.api_endpoint:
            try:
                response = requests.post(
                    f"{st.session_state.api_endpoint}/events",
                    json={"page": test_page, "action": test_action},
                    timeout=10
                )
                if response.status_code == 201:
                    st.success("✅ Event sent!")
                else:
                    st.error(f"❌ Error: {response.status_code}")
            except Exception as e:
                st.error(f"❌ Error: {str(e)}")
        else:
            st.warning("⚠️ Set API endpoint first")

# Main content
st.title("📊 Serverless Analytics Dashboard")
st.markdown("Real-time monitoring powered by **AWS Free Tier**")

# Check if API endpoint is configured
if not st.session_state.api_endpoint:
    st.warning("⚠️ Please configure your API Gateway endpoint in the sidebar")
    st.info("""
    **Quick Start:**
    1. Deploy the CloudFormation stack
    2. Copy the API endpoint from outputs
    3. Paste it in the sidebar
    4. Start monitoring! 🚀
    """)
    st.stop()

# Fetch data function
@st.cache_data(ttl=30)
def fetch_health():
    """Check API health"""
    try:
        response = requests.get(
            f"{st.session_state.api_endpoint}/health",
            timeout=5
        )
        return response.status_code == 200
    except:
        return False

@st.cache_data(ttl=30)
def fetch_stats(period="24h"):
    """Fetch analytics statistics"""
    try:
        response = requests.get(
            f"{st.session_state.api_endpoint}/stats",
            params={"period": period},
            timeout=10
        )
        if response.status_code == 200:
            return response.json()
        return None
    except Exception as e:
        st.error(f"Error fetching stats: {str(e)}")
        return None

@st.cache_data(ttl=30)
def fetch_recent_events(limit=20):
    """Fetch recent events"""
    try:
        response = requests.get(
            f"{st.session_state.api_endpoint}/events/recent",
            params={"limit": limit},
            timeout=10
        )
        if response.status_code == 200:
            return response.json()
        return None
    except Exception as e:
        st.error(f"Error fetching events: {str(e)}")
        return None

# Health check
is_healthy = fetch_health()

# Metrics row
col1, col2, col3, col4 = st.columns(4)

# Fetch stats
stats = fetch_stats(period)

if stats:
    with col1:
        st.metric(
            label="📊 Total Events",
            value=f"{stats.get('total_events', 0):,}",
            delta=f"{period} period"
        )
    
    with col2:
        top_pages = stats.get('top_pages', [])
        top_page = top_pages[0]['page'] if top_pages else 'N/A'
        st.metric(
            label="🔥 Top Page",
            value=top_page,
            delta=f"{top_pages[0]['count']} views" if top_pages else None
        )
    
    with col3:
        actions = stats.get('actions', {})
        total_actions = sum(actions.values())
        st.metric(
            label="🎯 Total Actions",
            value=f"{total_actions:,}",
            delta=f"{len(actions)} types"
        )
    
    with col4:
        status_color = "🟢" if is_healthy else "🔴"
        st.metric(
            label="💚 API Status",
            value=f"{status_color} {'Healthy' if is_healthy else 'Down'}"
        )
else:
    with col1:
        st.metric("📊 Total Events", "N/A")
    with col2:
        st.metric("🔥 Top Page", "N/A")
    with col3:
        st.metric("🎯 Total Actions", "N/A")
    with col4:
        status_color = "🟢" if is_healthy else "🔴"
        st.metric("💚 API Status", f"{status_color} {'Healthy' if is_healthy else 'Down'}")

st.divider()

# Charts section
if stats:
    col1, col2 = st.columns(2)
    
    with col1:
        st.subheader("📈 Events by Hour")
        
        # Parse hourly data
        hourly_data = stats.get('hourly_distribution', {})
        if hourly_data:
            df_hourly = pd.DataFrame([
                {'hour': k, 'events': v}
                for k, v in sorted(hourly_data.items())
            ])
            
            fig_hourly = px.bar(
                df_hourly,
                x='hour',
                y='events',
                title='Events Distribution',
                labels={'hour': 'Hour', 'events': 'Events'},
                color='events',
                color_continuous_scale='Blues'
            )
            fig_hourly.update_layout(
                showlegend=False,
                height=400,
                xaxis_title="Time",
                yaxis_title="Events"
            )
            st.plotly_chart(fig_hourly, use_container_width=True)
        else:
            st.info("No hourly data available yet")
    
    with col2:
        st.subheader("🎯 Events by Action")
        
        # Parse actions data
        actions = stats.get('actions', {})
        if actions:
            df_actions = pd.DataFrame([
                {'action': k, 'count': v}
                for k, v in actions.items()
            ])
            
            fig_actions = px.pie(
                df_actions,
                values='count',
                names='action',
                title='Action Distribution',
                color_discrete_sequence=px.colors.qualitative.Set3
            )
            fig_actions.update_traces(textposition='inside', textinfo='percent+label')
            fig_actions.update_layout(height=400)
            st.plotly_chart(fig_actions, use_container_width=True)
        else:
            st.info("No action data available yet")
    
    st.divider()
    
    # Top Pages section
    st.subheader("🔥 Top Pages")
    
    top_pages = stats.get('top_pages', [])
    if top_pages:
        # Create DataFrame
        df_pages = pd.DataFrame(top_pages)
        
        # Create horizontal bar chart
        fig_pages = px.bar(
            df_pages,
            x='count',
            y='page',
            orientation='h',
            title=f'Top {len(df_pages)} Pages',
            labels={'count': 'Views', 'page': 'Page'},
            color='count',
            color_continuous_scale='Viridis'
        )
        fig_pages.update_layout(
            showlegend=False,
            height=400,
            yaxis={'categoryorder': 'total ascending'}
        )
        st.plotly_chart(fig_pages, use_container_width=True)
        
        # Table view
        with st.expander("📋 View as Table"):
            st.dataframe(
                df_pages,
                use_container_width=True,
                hide_index=True,
                column_config={
                    "page": st.column_config.TextColumn("Page", width="large"),
                    "count": st.column_config.NumberColumn("Views", format="%d")
                }
            )
    else:
        st.info("No page data available yet")

st.divider()

# Recent Events section
st.subheader("⏱️ Recent Events (Live)")

recent_data = fetch_recent_events(20)

if recent_data and recent_data.get('events'):
    events = recent_data['events']
    
    # Create DataFrame
    df_events = pd.DataFrame(events)
    
    # Format timestamp
    if 'timestamp' in df_events.columns:
        df_events['time'] = pd.to_datetime(df_events['timestamp']).dt.strftime('%H:%M:%S')
    
    # Display as cards
    for i, event in enumerate(events[:10]):  # Show last 10
        timestamp = event.get('timestamp', '')
        if timestamp:
            time_str = datetime.fromisoformat(timestamp.replace('Z', '+00:00')).strftime('%H:%M:%S')
        else:
            time_str = 'N/A'
        
        col1, col2, col3 = st.columns([2, 3, 2])
        with col1:
            st.text(f"🕐 {time_str}")
        with col2:
            st.text(f"📄 {event.get('page', 'N/A')}")
        with col3:
            st.text(f"🎯 {event.get('action', 'N/A')}")
        
        if i < 9:  # Don't show divider after last item
            st.markdown("---")
    
    # Full table view
    with st.expander("📋 View All Events"):
        display_df = df_events[['time', 'page', 'action']].copy() if 'time' in df_events.columns else df_events
        st.dataframe(
            display_df,
            use_container_width=True,
            hide_index=True
        )
else:
    st.info("No recent events yet. Send a test event from the sidebar!")

# Footer
st.divider()
st.markdown("""
    <div style='text-align: center; color: gray; padding: 20px;'>
        <p>🚀 Serverless Analytics API • Powered by AWS Free Tier</p>
        <p style='font-size: 0.9em;'>Lambda + API Gateway + DynamoDB + S3 + CloudWatch</p>
    </div>
""", unsafe_allow_html=True)

# Auto-refresh logic
if auto_refresh:
    time.sleep(30)
    st.rerun()