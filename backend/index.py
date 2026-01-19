import json
import os
import uuid
from datetime import datetime, UTC

import ydb
import ydb.iam
from ydb import Driver, TableClient
from version import VERSION

DATABASE_ENDPOINT = os.getenv('DATABASE_ENDPOINT')
DATABASE_PATH = os.getenv('DATABASE_PATH')

def get_driver():
    driver = Driver(endpoint=DATABASE_ENDPOINT, database=DATABASE_PATH,credentials=ydb.iam.MetadataUrlCredentials(),)
    driver.wait(timeout=10)
    return driver

def get_messages(driver):
    table_client = TableClient(driver)
    session = table_client.session().create()

    query = """
    SELECT id, name, message, timestamp
    FROM messages
    ORDER BY timestamp DESC
    """

    result = session.transaction().execute(query, commit_tx=True)

    messages = []
    for row in result[0].rows:
        timestamp_seconds = row.timestamp / 1_000_000
        dt = datetime.fromtimestamp(timestamp_seconds, tz=UTC)
        
        messages.append({
            'id': row.id,
            'name': row.name,
            'message': row.message,
            'timestamp': dt.isoformat()
        })

    return messages
def post_message(driver, data):
    table_client = TableClient(driver)
    session = table_client.session().create()

    message_id = str(uuid.uuid4())
    timestamp = datetime.utcnow()

    query = """
    DECLARE $id AS Utf8;
    DECLARE $name AS Utf8;
    DECLARE $message AS Utf8;
    DECLARE $timestamp AS Timestamp;

    INSERT INTO messages (id, name, message, timestamp)
    VALUES ($id, $name, $message, $timestamp)
    """
    
    prepared = session.prepare(query)
    
    session.transaction().execute(
        prepared,
        parameters={
            '$id': message_id,
            '$name': data['name'],
            '$message': data['message'],
            '$timestamp': timestamp
        },
        commit_tx=True
    )

    return message_id

def handler(event, context):
    request_context = None
    http_method = None
    path = None
    func_version = None
    try:
        request_context = event.get('requestContext', {})
        http_method = event.get('httpMethod', '')
        path = event.get('path', '')
        func_version = context.function_version


        if 'version' in path and http_method == 'GET':
                return {
                    'statusCode': 200,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({'version': VERSION, 'function_version': func_version}),
                }
        elif 'messages' in path:
            driver = get_driver()
            if http_method == 'GET':
                messages = get_messages(driver)
                return {
                    'statusCode': 200,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps(messages)
                }
            elif http_method == 'POST':
                body = json.loads(event.get('body', '{}'))
                message_id = post_message(driver, body)
                return {
                    'statusCode': 201,
                    'headers': {'Content-Type': 'application/json'},
                    'body': json.dumps({'id': message_id})
                }
            driver.stop()

        return {
            'statusCode': 404,
            'body': json.dumps({
                'error': 'Not Found','path': path,
                'http_method': http_method,
                'event': event,
                'request_context': request_context,
                'context': context,
            }),
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e), 
                'path': path,
                'http_method': http_method,
                'event': event,
                'request_context': request_context,
                'context': context,
                }),
        }