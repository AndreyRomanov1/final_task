#!/bin/bash

source ../config.sh

echo "Starting destruction..."

echo "Deleting API Gateway..."
yc serverless api-gateway delete --name $YC_API_GATEWAY_NAME --folder-id $YC_FOLDER_ID

echo "Deleting Serverless Function..."
yc serverless function delete --name $YC_FUNCTION_NAME --folder-id $YC_FOLDER_ID

echo "Deleting Object Storage bucket..."
yc storage s3 rm --recursive s3://$YC_BUCKET_NAME/
yc storage bucket delete --name $YC_BUCKET_NAME

echo "Deleting Yandex Database..."
yc ydb database delete --name $YC_DB_NAME --folder-id $YC_FOLDER_ID

echo "Deleting Service Account..."
yc iam service-account delete --name $YC_SA_NAME --folder-id $YC_FOLDER_ID

echo "All resources destroyed!"