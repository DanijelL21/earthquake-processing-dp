#!/bin/bash

set -e

DEPLOYMENT_ENV=${1:-dev}
EXEC=${2:-local}
ACTION=${3:-deploy}
REGION=${4:-us-east-1}

if [ "$EXEC" = "local" ]; then
    export PIPENV_PIPFILE=../Pipfile
    pipenv lock -r > ../src/requirements.txt
fi

python ../one-deploy.py \
    --environment=${DEPLOYMENT_ENV} \
    --exec=${EXEC} \
    --action=${ACTION}