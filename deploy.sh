#!/bin/bash

#export AWS_PROFILE=<your-profile>

pip3 install --target ./package python-irodsclient

pushd package
zip -r9 ../s3salmon.zip .
popd
zip -g s3salmon.zip s3salmon.py


aws lambda update-function-code \
--function-name s3salmon \
--environment {"Variables": {"IRODS_HOST": "$IRODS_HOST", "IRODS_PORT": "$IRODS_PORT", "IRODS_USER": "$IRODS_USER", "IRODS_PASSWORD": "$IRODS_PASSWORD", "IRODS_ZONE": "$IRODS_ZONE", "IRODS_S3_RESC": "$IRODS_S3_RESC", "IRODS_VAULT_PREFIX": "$IRODS_VAULT_PREFIX"}} \
--zip-file fileb://s3salmon.zip
