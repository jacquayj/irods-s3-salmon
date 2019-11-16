#!/bin/bash

#export AWS_PROFILE=bms-gen3-test
export AWS_PROFILE=bioteam-john

pip3 install --target ./package python-irodsclient

pushd package
zip -r9 ../icatupdater.zip .
popd
zip -g icatupdater.zip icatupdater.py

aws lambda create-function \
--function-name icatupdater \
--runtime python3.7 \
--zip-file fileb://icatupdater.zip \
--role arn:aws:iam::609971441117:role/lambda-s3-role \
--handler icatupdater.main

aws lambda add-permission --function-name icatupdater --principal s3.amazonaws.com \
--statement-id s3invoke --action "lambda:InvokeFunction" \
--source-arn arn:aws:s3:::jj-irods \
--source-account 098381893833


 #--role arn:aws:iam::098381893833:role/lambda-role \