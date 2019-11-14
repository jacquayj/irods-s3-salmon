#!/bin/bash

export AWS_PROFILE=bms-gen3-test

pip3 install --target ./package python-irodsclient

pushd package
zip -r9 ../function.zip .
popd
zip -g icatupdater.zip icatupdater.py

aws lambda create-function \
--function-name icatupdater \
--runtime python3.7 \
--zip-file fileb://icatupdater.zip \
--role arn:aws:iam::098381893833:role/lambda-role \
--handler icatupdater.main
