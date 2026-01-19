#!/bin/bash

source ../config.sh

echo "Reset frontend and Backend versions..."
echo 'const VERSION = "1.0";' > ../frontend/version.js
echo 'VERSION = "1.0"' > ../backend/version.py

echo "Creating Yandex Database..."
yc ydb database create --folder-id $YC_FOLDER_ID --name $YC_DB_NAME --serverless
DB_INFO=$(yc ydb database get --name $YC_DB_NAME --folder-id $YC_FOLDER_ID --format json)
DB_PATH=$(echo $DB_INFO | jq -r '.endpoint | split("?database=")[1]')

echo "Creating Service Account..."
yc iam service-account create --name $YC_SA_NAME --folder-id $YC_FOLDER_ID
SA_ID=$(yc iam service-account get --name $YC_SA_NAME --folder-id $YC_FOLDER_ID --format json | jq -r .id)
yc ydb database add-access-binding --name $YC_DB_NAME --role ydb.editor --subject serviceAccount:$SA_ID --folder-id $YC_FOLDER_ID

echo "Creating Object Storage bucket..."
yc storage bucket create \
  --name $YC_BUCKET_NAME
yc storage bucket update \
  --name $YC_BUCKET_NAME \
  --website-settings-from-file "website_config.json"
yc storage bucket update \
  --name $YC_BUCKET_NAME \
  --cors allowed-methods='[method-get]',allowed-methods='[method-post]',allowed-methods='[method-put]',allowed-methods='[method-delete]',allowed-methods='[method-head]',allowed-origins='*',allowed-headers='*'
yc storage bucket update --name $YC_BUCKET_NAME --public-read

echo "Uploading frontend..."
yc storage s3 cp --content-type text/html ../frontend/index.html s3://$YC_BUCKET_NAME/
yc storage s3 cp --content-type text/css ../frontend/style.css s3://$YC_BUCKET_NAME/
yc storage s3 cp --content-type application/javascript ../frontend/script.js s3://$YC_BUCKET_NAME/
yc storage s3 cp --content-type application/javascript ../frontend/version.js s3://$YC_BUCKET_NAME/

echo "Creating Serverless Function..."
yc serverless function create \
  --name $YC_FUNCTION_NAME \
  --folder-id $YC_FOLDER_ID
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
yc serverless function allow-unauthenticated-invoke \
  --name $YC_FUNCTION_NAME \
  --folder-id $YC_FOLDER_ID
FUNCTION_ID=$(yc serverless function get --name $YC_FUNCTION_NAME --folder-id $YC_FOLDER_ID --format json | jq -r .id)

echo "Creating API Gateway..."
SPEC_FILE="api_gateway_spec.json"
cat > $SPEC_FILE << EOF
{
  "openapi": "3.0.0",
  "info": {
    "title": "GuestBook API",
    "version": "1.0.0"
  },
  "paths": {
    "/": {
      "get": {
        "x-yc-apigateway-integration": {
          "type": "object_storage",
          "bucket": "$YC_BUCKET_NAME",
          "object": "index.html"
        }
      }
    },
    "/{path+}": {
      "parameters": [
        {
          "name": "path",
          "in": "path",
          "required": true,
          "schema": {
            "type": "string"
          }
        }
      ],
      "get": {
        "x-yc-apigateway-integration": {
          "type": "object_storage",
          "bucket": "$YC_BUCKET_NAME",
          "object": "{path}"
        }
      },
      "options": {
        "x-yc-apigateway-integration": {
          "type": "dummy",
          "http_code": 200,
          "http_headers": {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type"
          },
          "content": {
            "text/plain": "OK"
          }
        }
      }
    },
    "/version": {
      "get": {
        "x-yc-apigateway-integration": {
          "type": "cloud_functions",
          "function_id": "$FUNCTION_ID"
        }
      },
      "options": {
        "x-yc-apigateway-integration": {
          "type": "dummy",
          "http_code": 200,
          "http_headers": {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type"
          },
          "content": {
            "text/plain": "OK"
          }
        }
      }
    },
    "/messages": {
      "get": {
        "x-yc-apigateway-integration": {
          "type": "cloud_functions",
          "function_id": "$FUNCTION_ID"
        }
      },
      "post": {
        "x-yc-apigateway-integration": {
          "type": "cloud_functions",
          "function_id": "$FUNCTION_ID"
        }
      },
      "options": {
        "x-yc-apigateway-integration": {
          "type": "dummy",
          "http_code": 200,
          "http_headers": {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type"
          },
          "content": {
            "text/plain": "OK"
          }
        }
      }
    }
  }
}
EOF
yc serverless api-gateway create --name $YC_API_GATEWAY_NAME --spec $SPEC_FILE --folder-id $YC_FOLDER_ID
API_DOMAIN=$(yc serverless api-gateway get --name $YC_API_GATEWAY_NAME --folder-id $YC_FOLDER_ID --format json | jq -r .domain)

echo "Deployment complete!"
echo "Application URL: https://$API_DOMAIN"
echo ""
