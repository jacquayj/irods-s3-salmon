# irods-s3-salmon

`irods-s3-salmon` is a lambda function that swims upstream to update your data catalog, when S3 events occur. 

## Setup Instructions

1. Deploy lambda
```
$ git clone https://github.com/jacquayj/irods-s3-salmon.git
$ cd irods-s3-salmon

$ export AWS_PROFILE=<your-profile>           # bioteam-john
$ export AWS_ACCOUNT_ID=<your-aws-account-id> # 098381893833
$ export S3_BUCKET=<your-bucket>              # jj-irods
$ export LAMBDA_ROLE_ARN=<lambda-role-arn>    # arn:aws:iam::098381893833:role/lambda-role

$ ./create.sh
```

2. Setup S3 Events

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