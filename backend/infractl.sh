#!/bin/bash

set -e

DEPLOYMENT_ENV=${1:-dev}
ACTION=${2:-deploy}

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

deploy_pipeline(){
    echo "Initializing Terraform..."
    terraform init

    echo "Planning the deployment..."
    terraform plan -var="profile=$PROFILE"

    echo "Applying the plan..."
    terraform apply -var="profile=$PROFILE"
}

echo "Checking deployment environment..."
check_environment 

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