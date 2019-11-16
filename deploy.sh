#!/bin/bash

#export AWS_PROFILE=bms-gen3-test
export AWS_PROFILE=bioteam-john

pip3 install --target ./package python-irodsclient

pushd package
zip -r9 ../icatupdater.zip .
popd
zip -g icatupdater.zip icatupdater.py


aws lambda update-function-code \
--function-name icatupdater \
--zip-file fileb://icatupdater.zip
