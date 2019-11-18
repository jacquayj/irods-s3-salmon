#!/bin/bash

#export AWS_PROFILE=<your-profile>

pushd "$(dirname ${BASH_SOURCE[0]})"

pip3 install --target ./package python-irodsclient

pushd package
zip -r9 ../s3salmon.zip .
popd
zip -g s3salmon.zip s3salmon.py
zip -g s3salmon.zip secrets.py

aws lambda update-function-code \
--function-name s3salmon \
--zip-file fileb://s3salmon.zip

popd