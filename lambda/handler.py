"""
Serverless Analytics API - Lambda Handler
Processes analytics events and provides statistics
100% AWS Free Tier compatible
"""

import json
import boto3
import os
from datetime import datetime, timedelta
from decimal import Decimal
import uuid

# AWS Clients
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ.get('DYNAMODB_TABLE', 'analytics-events'))

# CORS Headers
CORS_HEADERS = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,X-Api-Key',
    'Access-Control-Allow-Methods': 'GET,POST,DELETE,OPTIONS'
}


def lambda_handler(event, context):
    """
    Main Lambda handler - routes requests to appropriate functions
    """
    print(f"Event: {json.dumps(event)}")
    
    http_method = event.get('httpMethod', '')
    path = event.get('path', '')
    
    # Route to appropriate handler
    if http_method == 'OPTIONS':
        return cors_response(200, {'message': 'OK'})
    
    elif http_method == 'POST' and path == '/events':
        return handle_create_event(event)
    
    elif http_method == 'GET' and path == '/stats':
        return handle_get_stats(event)
    
    elif http_method == 'GET' and path == '/events/recent':
        return handle_get_recent_events(event)
    
    elif http_method == 'GET' and path == '/health':
        return handle_health_check(event)
    
    elif http_method == 'DELETE' and path.startswith('/events'):
        return handle_delete_events(event)
    
    else:
        return cors_response(404, {'error': 'Not found'})


def handle_create_event(event):
    """
    POST /events - Create a new analytics event
    """
    try:
        # Parse request body
        body = json.loads(event.get('body', '{}'))
        
        # Validate required fields
        if not body.get('page') or not body.get('action'):
            return cors_response(400, {
                'error': 'Missing required fields: page, action'
            })
        
        # Create event
        event_id = str(uuid.uuid4())
        timestamp = datetime.utcnow().isoformat()
        
        item = {
            'event_id': event_id,
            'timestamp': timestamp,
            'page': body['page'],
            'action': body['action'],
            'user_agent': event.get('headers', {}).get('User-Agent', 'Unknown'),
            'ip': event.get('requestContext', {}).get('identity', {}).get('sourceIp', 'Unknown'),
            'metadata': body.get('metadata', {}),
            'ttl': int((datetime.utcnow() + timedelta(days=90)).timestamp())  # Auto-delete after 90 days
        }
        
        # Save to DynamoDB
        table.put_item(Item=item)
        
        return cors_response(201, {
            'message': 'Event created',
            'event_id': event_id,
            'timestamp': timestamp
        })
        
    except json.JSONDecodeError:
        return cors_response(400, {'error': 'Invalid JSON'})
    
    except Exception as e:
        print(f"Error creating event: {str(e)}")
        return cors_response(500, {'error': 'Internal server error'})


def handle_get_stats(event):
    """
    GET /stats - Get analytics statistics
    """
    try:
        # Query parameters
        params = event.get('queryStringParameters') or {}
        period = params.get('period', '24h')  # 24h, 7d, 30d
        
        # Calculate time range
        now = datetime.utcnow()
        if period == '24h':
            start_time = now - timedelta(hours=24)
        elif period == '7d':
            start_time = now - timedelta(days=7)
        elif period == '30d':
            start_time = now - timedelta(days=30)
        else:
            start_time = now - timedelta(hours=24)
        
        start_timestamp = start_time.isoformat()
        
        # Scan table (for Free Tier, this is acceptable with small data)
        response = table.scan()
        items = response.get('Items', [])
        
        # Filter by time range
        filtered_items = [
            item for item in items 
            if item.get('timestamp', '') >= start_timestamp
        ]
        
        # Calculate statistics
        total_events = len(filtered_items)
        
        # Count by page
        pages = {}
        for item in filtered_items:
            page = item.get('page', 'unknown')
            pages[page] = pages.get(page, 0) + 1
        
        # Count by action
        actions = {}
        for item in filtered_items:
            action = item.get('action', 'unknown')
            actions[action] = actions.get(action, 0) + 1
        
        # Events by hour (last 24 hours)
        hourly_events = {}
        for item in filtered_items:
            timestamp = item.get('timestamp', '')
            if timestamp:
                hour = timestamp[:13]  # YYYY-MM-DDTHH
                hourly_events[hour] = hourly_events.get(hour, 0) + 1
        
        # Top pages
        top_pages = sorted(pages.items(), key=lambda x: x[1], reverse=True)[:10]
        
        stats = {
            'period': period,
            'total_events': total_events,
            'top_pages': [{'page': p, 'count': c} for p, c in top_pages],
            'actions': actions,
            'hourly_distribution': hourly_events,
            'generated_at': now.isoformat()
        }
        
        return cors_response(200, stats)
        
    except Exception as e:
        print(f"Error getting stats: {str(e)}")
        return cors_response(500, {'error': 'Internal server error'})


def handle_get_recent_events(event):
    """
    GET /events/recent - Get recent events
    """
    try:
        # Query parameters
        params = event.get('queryStringParameters') or {}
        limit = int(params.get('limit', '20'))
        
        # Scan and get recent items
        response = table.scan(Limit=100)
        items = response.get('Items', [])
        
        # Sort by timestamp (descending)
        sorted_items = sorted(
            items,
            key=lambda x: x.get('timestamp', ''),
            reverse=True
        )[:limit]
        
        # Clean up items for response
        events = []
        for item in sorted_items:
            events.append({
                'event_id': item.get('event_id'),
                'timestamp': item.get('timestamp'),
                'page': item.get('page'),
                'action': item.get('action'),
                'metadata': item.get('metadata', {})
            })
        
        return cors_response(200, {
            'events': events,
            'count': len(events)
        })
        
    except Exception as e:
        print(f"Error getting recent events: {str(e)}")
        return cors_response(500, {'error': 'Internal server error'})


def handle_health_check(event):
    """
    GET /health - Health check endpoint
    """
    return cors_response(200, {
        'status': 'healthy',
        'timestamp': datetime.utcnow().isoformat(),
        'service': 'analytics-api'
    })


def handle_delete_events(event):
    """
    DELETE /events - Delete old events (cleanup)
    """
    try:
        # Query parameters
        params = event.get('queryStringParameters') or {}
        days_old = int(params.get('days', '90'))
        
        # Calculate cutoff date
        cutoff = datetime.utcnow() - timedelta(days=days_old)
        cutoff_timestamp = cutoff.isoformat()
        
        # Scan for old items
        response = table.scan()
        items = response.get('Items', [])
        
        # Filter old items
        old_items = [
            item for item in items
            if item.get('timestamp', '') < cutoff_timestamp
        ]
        
        # Delete old items
        deleted_count = 0
        for item in old_items:
            table.delete_item(Key={'event_id': item['event_id']})
            deleted_count += 1
        
        return cors_response(200, {
            'message': f'Deleted {deleted_count} old events',
            'deleted_count': deleted_count
        })
        
    except Exception as e:
        print(f"Error deleting events: {str(e)}")
        return cors_response(500, {'error': 'Internal server error'})


def cors_response(status_code, body):
    """
    Helper function to return CORS-enabled response
    """
    return {
        'statusCode': status_code,
        'headers': CORS_HEADERS,
        'body': json.dumps(body, default=decimal_default)
    }


def decimal_default(obj):
    """
    Helper to serialize Decimal objects
    """
    if isinstance(obj, Decimal):
        return int(obj)
    raise TypeError