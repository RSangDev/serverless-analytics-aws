# tests/test_handler.py
import pytest
from lambda.handler import lambda_handler

def test_health_check():
    event = {
        'httpMethod': 'GET',
        'path': '/health'
    }
    response = lambda_handler(event, None)
    assert response['statusCode'] == 200

def test_create_event():
    event = {
        'httpMethod': 'POST',
        'path': '/events',
        'body': '{"page": "/test", "action": "view"}'
    }
    response = lambda_handler(event, None)
    assert response['statusCode'] == 201