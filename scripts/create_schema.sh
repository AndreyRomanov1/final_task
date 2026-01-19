#!/bin/bash

source ../config.sh

DB_INFO=$(yc ydb database get --name $YC_DB_NAME --folder-id $YC_FOLDER_ID --format json)
DB_PATH=$(echo $DB_INFO | jq -r '.endpoint | split("?database=")[1]')

echo "Creating temporary schema function..."
yc serverless function create --name temp-schema-creator --folder-id $YC_FOLDER_ID

SA_ID=$(yc iam service-account get --name $YC_SA_NAME --folder-id $YC_FOLDER_ID --format json | jq -r .id)

yc serverless function version create \
  --function-name temp-schema-creator \
  --runtime python312 \
  --entrypoint schema.handler \
  --source-path ../backend/ \
  --environment DATABASE_ENDPOINT=grpcs://ydb.serverless.yandexcloud.net:2135,DATABASE_PATH=$DB_PATH \
  --service-account-id $SA_ID \
  --folder-id $YC_FOLDER_ID \
  --execution-timeout 60s \
  --memory 1GB

FUNCTION_ID=$(yc serverless function get --name temp-schema-creator --folder-id $YC_FOLDER_ID --format json | jq -r .id)

echo "Invoking function to create schema..."
yc serverless function invoke --id $FUNCTION_ID --data '{}'

echo "Deleting temporary function..."
yc serverless function delete --name temp-schema-creator --folder-id $YC_FOLDER_ID

echo "Schema created successfully!"