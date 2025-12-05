#!/bin/bash
set -e

S3_BUCKET="${S3_BUCKET:-premyom}"
S3_ENDPOINT="${S3_ENDPOINT:-http://minio-gateway.minio.svc.cluster.local:9000}"
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
MOUNT_POINT="/mnt/dataset"

mkdir -p "$MOUNT_POINT"

echo "${AWS_ACCESS_KEY_ID}:${AWS_SECRET_ACCESS_KEY}" > /tmp/passwd-s3fs
chmod 600 /tmp/passwd-s3fs

s3fs "${S3_BUCKET}" "$MOUNT_POINT" -o passwd_file=/tmp/passwd-s3fs -o url="${S3_ENDPOINT}" -o use_path_request_style -o nonempty

exec /usr/local/bin/code-server "$@"
