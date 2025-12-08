#!/bin/bash
set -e

# Paramètres S3 : par défaut on vise Clever Cloud (Cellar), mais tout
# peut être surchargé via les variables d'environnement (Vault / Onyxia).
S3_BUCKET="${S3_BUCKET:-premyom}"
S3_ENDPOINT="${S3_ENDPOINT:-https://cellar-c2.services.clever-cloud.com}"
AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"
AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
MOUNT_POINT="${MOUNT_POINT:-/mnt/dataset}"

mkdir -p "$MOUNT_POINT"

if [ -n "${AWS_ACCESS_KEY_ID}" ] && [ -n "${AWS_SECRET_ACCESS_KEY}" ]; then
  echo "${AWS_ACCESS_KEY_ID}:${AWS_SECRET_ACCESS_KEY}" > /tmp/passwd-s3fs
  chmod 600 /tmp/passwd-s3fs

  s3fs "${S3_BUCKET}" "$MOUNT_POINT" \
    -o passwd_file=/tmp/passwd-s3fs \
    -o url="${S3_ENDPOINT}" \
    -o use_path_request_style \
    -o nonempty
fi

exec /usr/local/bin/code-server "$@"
