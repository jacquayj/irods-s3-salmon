#!/bin/bash

#export AWS_PROFILE=<your-profile>

pip3 install --target ./package python-irodsclient

pushd package
zip -r9 ../s3salmon.zip .
popd
zip -g s3salmon.zip s3salmon.py

aws lambda create-function \
--function-name s3salmon \
--runtime python3.7 \
--zip-file fileb://s3salmon.zip \
--role $LAMBDA_ROLE_ARN \
--handler s3salmon.main

aws lambda add-permission --function-name s3salmon --principal s3.amazonaws.com \
--statement-id s3invoke --action "lambda:InvokeFunction" \
--source-arn arn:aws:s3:::$S3_BUCKET \
--source-account $AWS_ACCOUNT_ID
