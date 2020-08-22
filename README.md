# Usage #
Run the following to build image.  
```
packer build -var 'aws_access_key=<AWS-access-key>' -var 'aws_secret_key=<AWS-secret-key>' -var 'ami_name=<AMI-name>' -var 'account_name=<account-name>' build.json
```
**`aws_access_key`** is the AWS Access Key Id used for programmatic (API) access to AWS services.  
**`aws_secret_key`** is the AWS Secret Key Id used for programmatic (API) access to AWS services.  
**`ami_name`** is the name of AMI.  
**`account_name (Optional)`** is the user name used in script for locking unnecessary account and adding a custom new user.  
