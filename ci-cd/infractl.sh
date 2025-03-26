#!/bin/bash

set -e

DEPLOYMENT_ENV=${1:-dev}
ACTION=${2:-deploy}
REGION=${3:-us-east-1}

FOLDER_NAME="$(basename "$(dirname "$(realpath "$0")")")"

check_environment(){
    case "$DEPLOYMENT_ENV" in
        dev)
            PROFILE=aws-acct-training.AdministratorAccess
            echo "Selected deployment environment: $DEPLOYMENT_ENV"
            ;;

        preprod)
            PROFILE=aws-acct-training-preprod.AdministratorAccess
            echo "Selected deployment environment: $DEPLOYMENT_ENV"
            ;;

        prod)
            PROFILE=aws-acct-training-prod.AdministratorAccess
            echo "Selected deployment environment: $DEPLOYMENT_ENV"
            ;;

        *)
            echo "Invalid deployment environment: $DEPLOYMENT_ENV. Please select dev, preprod or prod"
            exit 1
    esac
    export AWS_PROFILE=$PROFILE
}

init_pipeline(){
    echo "Initializing Terraform..."
    S3_BUCKET=$(aws ssm get-parameter --name "/backend/s3_bucket" --query "Parameter.Value" --output text)
    echo "Artifacts stored in $S3_BUCKET"

    terraform init \
            -backend-config="key=$DEPLOYMENT_ENV/$FOLDER_NAME/terraform.tfstate" \
            -backend-config="region=$REGION" \
            -backend-config="profile=$PROFILE" \
            -backend-config="bucket=$S3_BUCKET"
}

deploy_pipeline(){
    echo "Planning the deployment..."
    terraform plan -var="profile=$PROFILE" -var="environment=$DEPLOYMENT_ENV"

    echo "Applying the plan..."
    # terraform -chdir=../ apply -auto-approve -var="profile=$PROFILE"
    terraform apply -var="profile=$PROFILE" -var="environment=$DEPLOYMENT_ENV"
}

echo "Checking deployment environment..."
check_environment 
init_pipeline

if [ "$ACTION" == "destroy" ]; then
    echo "Destroying ${STACK_NAME} in $DEPLOYMENT_ENV environment."
    terraform destroy -var="profile=$PROFILE"
elif [ "$ACTION" == "deploy" ]; then
    echo "Deploying ${STACK_NAME} in $DEPLOYMENT_ENV environment."
    deploy_pipeline
else
    echo "Invalid action: $ACTION. Please use 'deploy' or 'destroy'."
    exit 1
fi