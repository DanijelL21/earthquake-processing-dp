#!/bin/bash

set -e

DEPLOYMENT_ENV=${1:-dev}
EXEC=${2:-local}
ACTION=${3:-deploy}
REGION=${4:-us-east-1}

FOLDER_NAME="$(basename "$(dirname "$(realpath "$0")")")"

case "${EXEC}" in 
    local)
        if [[ "${DEPLOYMENT_ENV}" == "dev" ]]; then
            PROFILE="aws-acct-training.AdministratorAccess"
        elif [[ "${DEPLOYMENT_ENV}" == "preprod" ]]; then
            PROFILE="aws-acct-training-preprod.AdministratorAccess"
        elif [[ "${DEPLOYMENT_ENV}" == "prod" ]]; then
            PROFILE=aws-acct-training-prod.AdministratorAccess
        else 
            echo "Invalid deployment environment: $DEPLOYMENT_ENV. Please select dev, preprod or prod"
            exit 1
        fi

        S3_BUCKET=$(aws ssm get-parameter --name "/backend/s3_bucket" --query "Parameter.Value" --output text --region $REGION --profile $PROFILE)
        echo "Artifacts stored in $S3_BUCKET"

        echo "Initializing Terraform..."
        terraform init \
            -backend-config="key=$DEPLOYMENT_ENV/$FOLDER_NAME/terraform.tfstate" \
            -backend-config="region=$REGION" \
            -backend-config="profile=$PROFILE" \
            -backend-config="bucket=$S3_BUCKET"

        if [ "$ACTION" == "destroy" ]; then
            echo "Destroying ${STACK_NAME} in $DEPLOYMENT_ENV environment."
            terraform destroy -var="profile=$PROFILE"
        elif [ "$ACTION" == "deploy" ]; then
            echo "Planning the deployment..."
            terraform plan -var="profile=$PROFILE"

            echo "Applying the plan..."
            terraform apply -auto-approve -var="profile=$PROFILE"
        else
            echo "Invalid action: $ACTION. Please use 'deploy' or 'destroy'."
            exit 1
        fi
        ;;
    pipeline)
        S3_BUCKET=$(aws ssm get-parameter --name "/backend/s3_bucket" --query "Parameter.Value" --output text)
        echo "Artifacts stored in $S3_BUCKET"

        echo "Initializing Terraform..."
        terraform init \
            -backend-config="key=$DEPLOYMENT_ENV/$FOLDER_NAME/terraform.tfstate" \
            -backend-config="bucket=$S3_BUCKET"

        if [ "$ACTION" == "destroy" ]; then
            echo "Destroying ${STACK_NAME} in $DEPLOYMENT_ENV environment."
            terraform destroy
        elif [ "$ACTION" == "deploy" ]; then
            echo "Planning the deployment..."
            terraform plan 

            echo "Applying the plan..."
            terraform apply -auto-approve
        else
            echo "Invalid action: $ACTION. Please use 'deploy' or 'destroy'."
            exit 1
        fi
        ;;
esac 