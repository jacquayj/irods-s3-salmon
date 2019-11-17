#!/bin/bash

#export AWS_PROFILE=<your-profile>

pip3 install --target ./package python-irodsclient

pushd package
zip -r9 ../s3salmon.zip .
popd
zip -g s3salmon.zip s3salmon.py

aws lambda update-function-code \
--function-name s3salmon \
--zip-file fileb://s3salmon.zip
