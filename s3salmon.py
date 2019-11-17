import os, ssl, logging, json
from irods.session import iRODSSession
from irods.exception import CATALOG_ALREADY_HAS_ITEM_BY_THAT_NAME, S3_FILE_STAT_ERR
from secrets import get_secret
import urllib.parse

IRODS_HOST = os.getenv('IRODS_HOST')
IRODS_PORT = int(os.getenv('IRODS_PORT'))
IRODS_ZONE = os.getenv('IRODS_ZONE')
IRODS_S3_RESC = os.getenv('IRODS_S3_RESC')
IRODS_VAULT_PREFIX = os.getenv('IRODS_VAULT_PREFIX')
AWS_SECRET_REGION = os.getenv('AWS_SECRET_REGION')

logger = logging.getLogger("icatupdater")
logger.setLevel(logging.INFO)

def remove_prefix(text, prefix):
    if text.startswith(prefix):
        return text[len(prefix):]
    return text 

def main(event, context):

    try:
        secrets = json.loads(get_secret(AWS_SECRET_REGION))
    except Exception as e:
        logger.error("Unable to load secrets: {}".format(str(e)))
        exit(1)
        
    logger.info("Opening iRODS session")
    with iRODSSession(host=IRODS_HOST, port=IRODS_PORT, user=secrets['s3salmon_user'], password=secrets['s3salmon_password'], zone=IRODS_ZONE) as session:
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
            except S3_FILE_STAT_ERR as e:
                logger.error("iRODS not able to find {} in S3".format(s3_physical))
                exit(1)
            except Exception as e:
                logger.error(str(e))
                exit(1)
        elif "ObjectRemoved" in event_name:
            try:
                session.data_objects.unregister("/{}{}".format(IRODS_ZONE, rods_path))
            except Exception as e:
                logger.error(str(e))
                exit(1)

        logger.info("Done!")

        return { 
            'message' : "Updated iRODS object record {}".format(object_key)
        }