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

**NOTE:** This has only been tested with `cacheless_attached` mode with [irods_resource_plugin_s3](https://github.com/irods/irods_resource_plugin_s3)

## Setup Instructions

1. Create lambda execution role, take note of ARN string

    https://docs.aws.amazon.com/lambda/latest/dg/lambda-intro-execution-role.html

2. Deploy lambda
    
    ```
    $ git clone https://github.com/jacquayj/irods-s3-salmon.git
    $ cd irods-s3-salmon
    ```
    
    **Modify config in env.sh with your iRODS environment customizations**

    ```
    $ ./create.sh
    ```

3. Setup S3 Events

    1. Open the Amazon S3 console.
    2. Choose the source bucket.
    3. Choose Properties.
    4. Under Events, configure a notification with the following settings.
        * Name – lambda-trigger.
        * Events – "All object create events", "All object delete events".
        * Send to – Lambda function.
        * Lambda – s3salmon.

    https://docs.aws.amazon.com/AmazonS3/latest/user-guide/enable-event-notifications.html

## Update Lambda

```
$ ./deploy.sh
```

## Lambda Code

```python
import os, ssl, logging
from irods.session import iRODSSession
from irods.exception import CATALOG_ALREADY_HAS_ITEM_BY_THAT_NAME
import urllib.parse

IRODS_HOST = os.getenv('IRODS_HOST')
IRODS_PORT = int(os.getenv('IRODS_PORT'))
IRODS_USER = os.getenv('IRODS_USER')
IRODS_PASSWORD = os.getenv('IRODS_PASSWORD')
IRODS_ZONE = os.getenv('IRODS_ZONE')
IRODS_S3_RESC = os.getenv('IRODS_S3_RESC')
IRODS_VAULT_PREFIX = os.getenv('IRODS_VAULT_PREFIX')

logger = logging.getLogger("icatupdater")
logger.setLevel(logging.INFO)

def remove_prefix(text, prefix):
    if text.startswith(prefix):
        return text[len(prefix):]
    return text 

def main(event, context):

    logger.info("Opening iRODS session")
    with iRODSSession(host=IRODS_HOST, port=IRODS_PORT, user=IRODS_USER, password=IRODS_PASSWORD, zone=IRODS_ZONE) as session:
        event_name = event['Records'][0]['eventName']
        bucket_name = event['Records'][0]['s3']['bucket']['name']
        object_key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key']) # irods/Vault/home/rods/requirements.txt
        rods_path = remove_prefix(object_key, IRODS_VAULT_PREFIX) # /home/rods/requirements.txt

        logger.info("Processing {} for s3://{}/{}".format(event_name, bucket_name, object_key))

        # https://docs.aws.amazon.com/AmazonS3/latest/dev/NotificationHowTo.html#supported-notification-event-types
        if "ObjectCreated" in event_name:
            irods_logical = "/{}{}".format(IRODS_ZONE, rods_path)
            s3_physical = "/{}/{}".format(bucket_name, object_key)

            try:
                session.data_objects.register(s3_physical, irods_logical, rescName=IRODS_S3_RESC)
            except CATALOG_ALREADY_HAS_ITEM_BY_THAT_NAME as e:
                session.data_objects.unregister(irods_logical)
                session.data_objects.register(s3_physical, irods_logical, rescName=IRODS_S3_RESC)
        elif "ObjectRemoved" in event_name:
            try:
                session.data_objects.unregister("/{}{}".format(IRODS_ZONE, rods_path))
            except Exception as e:
                logger.error(str(e))

        logger.info("Done!")
        return { 
            'message' : "Updated iRODS object record {}".format(object_key)
        }
```