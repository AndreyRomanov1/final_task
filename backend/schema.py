import os
import ydb
import ydb.iam
from ydb import Driver, TableClient

DATABASE_ENDPOINT = os.getenv('DATABASE_ENDPOINT')
DATABASE_PATH = os.getenv('DATABASE_PATH')

def get_driver():
    driver = Driver(endpoint=DATABASE_ENDPOINT, database=DATABASE_PATH, credentials=ydb.iam.MetadataUrlCredentials())
    driver.wait(timeout=10)
    return driver

def create_table(driver):
    table_client = TableClient(driver)
    session = table_client.session().create()

    query = """
    CREATE TABLE IF NOT EXISTS messages (
        id Utf8,
        name Utf8,
        message Utf8,
        timestamp Timestamp,
        PRIMARY KEY (id)
    );
    """

    session.execute_scheme(query)

def handler(event, context):
    try:
        driver = get_driver()
        create_table(driver)
        driver.stop()
        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': '{"message": "Schema created successfully"}'
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': f'{{"error": "{str(e)}"}}'
        }