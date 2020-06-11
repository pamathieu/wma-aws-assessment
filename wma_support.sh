#!/usr/bin/env bash
###############
#  This is file is used a support to run bash scripts
#
#   Pierre Mathieu, 08/25/2018
################

## Create S3 bucket to save the Terraform Backend State
aws s3 mb s3://wma-terraform-state  --profile=terraform --region=us-east-1


## To find the private IP of the Private instance
aws ec2 describe-instances --filters 'Name=tag:Name,Values=WMA Private Instance' 'Name=instance-state-name,Values=running'  --output json --profile=terraform --region=us-east-1 | \
 python3 -c "import sys, json; print(json.load(sys.stdin)['Reservations'][0]['Instances'][0]['PrivateIpAddress'])"


## To find the private IP of the Jumpbox
aws ec2 describe-instances --filters 'Name=tag:Name,Values=WMA Public Instance'v'Name=instance-state-name,Values=running'  --output json --profile=terraform --region=us-east-1 | \
 python3 -c "import sys, json; print(json.load(sys.stdin)['Reservations'][0]['Instances'][0]['PrivateIpAddress'])"

## To find the public IP of the Jumpbox
 aws ec2 describe-instances --filters 'Name=tag:Name,Values=WMA Public Instance' 'Name=instance-state-name,Values=running'  --output json --profile=terraform --region=us-east-1 | \
 python3 -c "import sys, json; print(json.load(sys.stdin)['Reservations'][0]['Instances'][0]['PublicIpAddress'])"





## Create ssh key-pair: wma-deploy-key.pem and wma-deploy-key.pub
ssh-keygen


## store  key in AWS Secret Manager ..
aws secretsmanager create-secret --name wma-ssh-deploy-key \
    --description "Private Key-pair for WMA deployment" \
    --secret-string file://~/.ssh/wmadeploykey.pem  --profile=home --region=us-east-1

## delete key from local machine. All accesses must be via API call of the AWS Secret Manager
rm ~/.ssh/wma-key.pem

### aws secretsmanager update-secret --secret-id ssh-deploy-key  --description "Private key-pair for WMA deployment"  --profile=home --region=us-east-1
aws secretsmanager update-secret --secret-id ssh-deploy-key  --secret-string file://~/.ssh/wmadeploykey.pem   --profile=home --region=us-east-1
    ### aws secretsmanager delete-secret --secret-id ssh-deploy-key  --profile=home --region=us-east-1

## Retrieve key value
aws secretsmanager get-secret-value --secret-id  wma-ssh-deploy-key --profile=home --region=us-east-1 | \
    python3 -c "import sys, json; print(json.load(sys.stdin)['SecretString'])"


### To Run the Terraform scripts
    # Initiate the state, as onetime operation, unless it's needed. It initializes a Terraform working directory
    terraform init

    #Validate the Terraform files. In this case, variables.tf and main.tf
    terraform validate

    ## Validates the Terraform files to output the resources to add, change, and destroy.
    terraform plan -out wma.plan

     ## Validates the Terraform files to output the resources to add, change, and destroy.
    terraform apply




### Ansible Preparation. We will use the Jumbox as an Ansible Control Machine
    #Setup Ansible Control Machine
    sudo yum update -y
    sudo yum install python3 -y
    sudo yum install python3-pip -y
    sudo pip3 install ansible


