# irods-s3-salmon

<img align="left" src="salmon.jpg">

`irods-s3-salmon` is a lambda function that swims upstream to update your data catalog, when S3 events occur. Works alongside [irods_resource_plugin_s3](https://github.com/irods/irods_resource_plugin_s3) to enable live streaming updates from S3 buckets to iRODS.

    * No more stale and out-of-sync data catalogs
    * No more waiting for scheduled jobs to run  
    * No more orphaned data object records       

 ```
                             /`·.¸
                            /¸...¸`:·
                        ¸.·´  ¸   `·.¸.·´)
                       : © ):´;      ¸  {
                        `·.¸ `·  ¸.·´\`·¸)
                            `\\´´\¸.·´
 ```

**NOTE:** This has only been tested with `cacheless_attached` mode with [irods_resource_plugin_s3](https://github.com/irods/irods_resource_plugin_s3). Depends on [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html).

## Usage Example

```
$ aws s3 cp WGZ-jj.indel.vcf.gz s3://jj-irods/irods/Vault/home/rods/WGZ-jj.indel.vcf.gz
```

Instantly find the object in iRODS:

```
$ ils
/tempZone/home/rods:
  WGZ-jj.indel.vcf.gz
```

## Setup Instructions

1. Create lambda execution role, take note of ARN string

    - `SecretsManagerReadWrite`
    - `AWSLambdaExecute`

    https://console.aws.amazon.com/iam/home#/roles
    
    https://docs.aws.amazon.com/lambda/latest/dg/lambda-intro-execution-role.html

2. Create secrets

    - Type: `Other type of secrets`
    - Secret key/value #1: `s3salmon_user: rods`
    - Secret key/value #2: `s3salmon_password: testpassword`
    - Secret name: `s3salmon`

    https://console.aws.amazon.com/secretsmanager/home

3. Deploy lambda
    
    ```
    $ git clone https://github.com/jacquayj/irods-s3-salmon.git
    $ cd irods-s3-salmon
    ```
    
    **Important! Modify config in `env.sh` with your iRODS environment customizations**

    ```
    $ ./create.sh
    ```

4. Setup S3 Events

    1. Open the Amazon S3 console.
    2. Choose the source bucket.
    3. Choose Properties.
    4. Under Events, configure a notification with the following settings.
        * Name – `lambda-trigger`.
        * Events – `All object create events`, `All object delete events`.
        * Send to – `Lambda function`.
        * Lambda – `s3salmon`.

    https://docs.aws.amazon.com/AmazonS3/latest/user-guide/enable-event-notifications.html

## Update Lambda

```
$ ./deploy.sh
```

## Lambda Code

```python
import os, ssl, logging, json
from irods.session import iRODSSession
from irods.exception import CATALOG_ALREADY_HAS_ITEM_BY_THAT_NAME, S3_FILE_STAT_ERR, CAT_NO_ROWS_FOUND
from secrets import get_secret
import urllib.parse

IRODS_HOST = os.getenv('IRODS_HOST')
IRODS_PORT = int(os.getenv('IRODS_PORT'))
IRODS_ZONE = os.getenv('IRODS_ZONE')
IRODS_S3_RESC = os.getenv('IRODS_S3_RESC')
IRODS_VAULT_PREFIX = os.getenv('IRODS_VAULT_PREFIX')
AWS_SECRET_REGION = os.getenv('AWS_SECRET_REGION') or "us-east-1"
AWS_SECRET_NAME = os.getenv('AWS_SECRET_NAME') or "s3salmon"
AWS_SECRET_KEY_USER = os.getenv('AWS_SECRET_KEY_USER') or "s3salmon_user"
AWS_SECRET_KEY_PASS = os.getenv('AWS_SECRET_KEY_PASS') or "s3salmon_password"

logger = logging.getLogger("s3salmon")
logger.setLevel(logging.INFO)

def remove_prefix(text, prefix):
    if text.startswith(prefix):
        return text[len(prefix):]
    return text 

def main(event, context):
    try:
        secrets = json.loads(get_secret(AWS_SECRET_REGION, AWS_SECRET_NAME))
    except Exception as e:
        logger.error("Unable to load secrets: {}".format(str(e)))
        exit(1)

    if AWS_SECRET_KEY_USER not in secrets or AWS_SECRET_KEY_PASS not in secrets:
        logger.error("Unable to find secrets in {} or {}".format(AWS_SECRET_KEY_USER, AWS_SECRET_KEY_PASS))
        exit(1)

    logger.info("Opening iRODS session")
    with iRODSSession(host=IRODS_HOST, port=IRODS_PORT, user=secrets[AWS_SECRET_KEY_USER], password=secrets[AWS_SECRET_KEY_PASS], zone=IRODS_ZONE) as session:
        event_name = event['Records'][0]['eventName']
        bucket_name = event['Records'][0]['s3']['bucket']['name']
        object_key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key']) # irods/Vault/home/rods/requirements.txt
        rods_path = remove_prefix(object_key, IRODS_VAULT_PREFIX) # /home/rods/requirements.txt

        logger.info("Processing {} for s3://{}/{}".format(event_name, bucket_name, object_key))

        if not object_key.startswith(IRODS_VAULT_PREFIX):
            # This object isn't exposed to iRODS, skip...
            logger.warning("Skipping object {}, isn't within Vault context {}. Consider setting Prefix filter to \"{}\" in S3 event config".format(object_key, IRODS_VAULT_PREFIX, IRODS_VAULT_PREFIX))
            exit(0)

        # https://docs.aws.amazon.com/AmazonS3/latest/dev/NotificationHowTo.html#supported-notification-event-types
        if "ObjectCreated" in event_name:
            irods_logical = "/{}{}".format(IRODS_ZONE, rods_path)
            s3_physical = "/{}/{}".format(bucket_name, object_key)

            try:
                session.data_objects.register(s3_physical, irods_logical, rescName=IRODS_S3_RESC)
            except CATALOG_ALREADY_HAS_ITEM_BY_THAT_NAME as e:
                session.data_objects.unregister(irods_logical)
                session.data_objects.register(s3_physical, irods_logical, rescName=IRODS_S3_RESC)
            except S3_FILE_STAT_ERR as e:
                logger.error("iRODS not able to find {} in S3: {}".format(s3_physical, repr(e)))
                exit(1)
            except Exception as e:
                logger.error(repr(e))
                exit(1)
        elif "ObjectRemoved" in event_name:
            try:
                session.data_objects.unregister("/{}{}".format(IRODS_ZONE, rods_path))
            except CAT_NO_ROWS_FOUND as e:
                logger.warning("Tried to unregister {} but the object was already unregistered: {}".format(rods_path, repr(e)))
            except Exception as e:
                logger.error(repr(e))
                exit(1)

        logger.info("Done!")

        return { 
            'message' : "Updated iRODS object record {}".format(object_key)
        }
```