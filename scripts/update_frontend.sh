#!/bin/bash

source ../config.sh

increment_version() {
    local file="../frontend/version.js"
    local current=$(grep 'const VERSION = ' "$file" | sed 's/.*= "//;s/".*//')
    IFS='.' read -ra parts <<< "$current"
    local last_index=$(( ${#parts[@]} - 1 ))
    parts[$last_index]=$(( parts[$last_index] + 1 ))
    local new_version=$(IFS='.'; echo "${parts[*]}")
    sed -i "s/const VERSION = \"$current\"/const VERSION = \"$new_version\"/" "$file"
}

increment_version

echo "Updating frontend..."
yc storage s3 cp --content-type text/html ../frontend/index.html s3://$YC_BUCKET_NAME/
yc storage s3 cp --content-type text/css ../frontend/style.css s3://$YC_BUCKET_NAME/
yc storage s3 cp --content-type application/javascript ../frontend/script.js s3://$YC_BUCKET_NAME/
yc storage s3 cp --content-type application/javascript ../frontend/version.js s3://$YC_BUCKET_NAME/