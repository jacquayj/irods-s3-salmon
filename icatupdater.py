import os, ssl, logging
from irods.session import iRODSSession
from irods.exception import CATALOG_ALREADY_HAS_ITEM_BY_THAT_NAME

IRODS_ZONE = "tempZone"
IRODS_S3_RESC = "s3resc"
IRODS_VAULT_PREFIX = "irods/Vault"

logger = logging.getLogger("icatupdater")
logger.setLevel(logging.INFO)

def remove_prefix(text, prefix):
    if text.startswith(prefix):
        return text[len(prefix):]
    return text 

def main(event, context):

    logger.info("Opening iRODS session")
    with iRODSSession(host='irods.johnjacquay.com', port=1247, user='rods', password='testpassword', zone='tempZone') as session:
        
        event_name = event['Records'][0]['eventName']
        bucket_name = event['Records'][0]['s3']['bucket']['name']
        object_key = event['Records'][0]['s3']['object']['key'] # irods/Vault/home/rods/requirements.txt
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