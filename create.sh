#!/bin/bash

#export AWS_PROFILE=<your-profile>

pushd "$(dirname ${BASH_SOURCE[0]})"

source env.sh

pip3 install --target ./package python-irodsclient

pushd package
zip -r9 ../s3salmon.zip .
popd
zip -g s3salmon.zip s3salmon.py
zip -g s3salmon.zip secrets.py

aws lambda create-function \
--function-name s3salmon \
--runtime python3.7 \
--zip-file fileb://s3salmon.zip \
--role $LAMBDA_ROLE_ARN \
--environment '{"Variables": {"AWS_SECRET_REGION": "'"$AWS_SECRET_REGION"'", "IRODS_HOST": "'"$IRODS_HOST"'", "IRODS_PORT": "'"$IRODS_PORT"'", "IRODS_ZONE": "'"$IRODS_ZONE"'", "IRODS_S3_RESC": "'"$IRODS_S3_RESC"'", "IRODS_VAULT_PREFIX": "'"$IRODS_VAULT_PREFIX"'"}}' \
--handler s3salmon.main

aws lambda add-permission --function-name s3salmon --principal s3.amazonaws.com \
--statement-id s3invoke --action "lambda:InvokeFunction" \
--source-arn arn:aws:s3:::$S3_BUCKET \
--source-account $AWS_ACCOUNT_ID

popd