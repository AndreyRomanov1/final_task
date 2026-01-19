#!/bin/bash

source ../config.sh

increment_version() {
    local file="../backend/version.py"
    local current=$(grep '^VERSION = ' "$file" | sed 's/.*= "//;s/".*//')
    IFS='.' read -ra parts <<< "$current"
    local last_index=$(( ${#parts[@]} - 1 ))
    parts[$last_index]=$(( parts[$last_index] + 1 ))
    local new_version=$(IFS='.'; echo "${parts[*]}")
    sed -i "s/VERSION = \"$current\"/VERSION = \"$new_version\"/" "$file"
}

increment_version

echo "Updating backend..."
DB_INFO=$(yc ydb database get --name $YC_DB_NAME --folder-id $YC_FOLDER_ID --format json)
DB_PATH=$(echo $DB_INFO | jq -r '.endpoint | split("?database=")[1]')
SA_ID=$(yc iam service-account get --name $YC_SA_NAME --folder-id $YC_FOLDER_ID --format json | jq -r .id)
yc serverless function version create \
  --function-name $YC_FUNCTION_NAME \
  --runtime python312 \
  --entrypoint index.handler \
  --source-path ../backend/ \
  --environment DATABASE_ENDPOINT=grpcs://ydb.serverless.yandexcloud.net:2135,DATABASE_PATH=$DB_PATH \
  --service-account-id $SA_ID \
  --folder-id $YC_FOLDER_ID \
  --execution-timeout 60s \
  --memory 1GB