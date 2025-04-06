import json
import os
import subprocess
import sys

import click


@click.command()
@click.option(
    "--environment",
    "-e",
    default="dev",
    show_default=True,
    help="Environment to deploy to",
)
@click.option(
    "--action",
    type=click.Choice(["deploy", "destroy"], case_sensitive=False),
    default="deploy",
    show_default=True,
    help="Action to perform (deploy or destroy)",
)
@click.option(
    "--region",
    "-r",
    default="us-east-1",
    show_default=True,
    help="Region to deploy to",
)
@click.option(
    "--exec",
    default="local",
    show_default=True,
)
@click.option(
    "--include_tfvars",
    is_flag=True,
    default=False,
    help="Include tfvars in deployment",
)
@click.option(
    "--vars",
    type=(str, str),
    multiple=True,
    help="Specify -var pairs (e.g. --vars key value). Example: --vars test Yes --vars environment dev",
)
def deploy(environment, action, region, exec, include_tfvars, vars):
    check_env(environment)

    init_command = f' terraform init \
        -backend-config="key={environment}/{os.path.basename(os.getcwd())}/terraform.tfstate"'
    plan_command = f" terraform plan"
    apply_command = f" terraform apply"
    destroy_command = f" terraform destroy"

    if include_tfvars:
        plan_command += " -var-file=terraform.tfvars"
        apply_command += " -var-file=terraform.tfvars"
        destroy_command += " -var-file=terraform.tfvars"

    if vars:
        for key, value in vars:
            plan_command += f' -var="{key}={value}"'
            apply_command += f' -var="{key}={value}"'
            destroy_command += f' -var="{key}={value}"'

    if exec == "local":
        profile = deployment_profile(environment)
        backend_bucket = get_backend_bucket(profile, region)

        init_command += f' -backend-config="region={region}" \
            -backend-config="profile={profile}" \
            -backend-config="bucket={backend_bucket}"'

        plan_command += f' -var="profile={profile}"'

        apply_command += f' -var="profile={profile}"'
        destroy_command += f' -var="profile={profile}"'

    elif exec == "pipeline":
        backend_bucket = get_backend_bucket()

        init_command += f' -backend-config="bucket={backend_bucket}"'
        apply_command += f" -auto-approve"

    else:
        print("Invalid exec option. Must be local or pipeline")
        sys.exit(1)

    print(f"Artifacts stored in {backend_bucket}")
    print("Initializing Terraform...")
    run_shell_command(init_command)

    if action == "deploy":
        print("Planning the deployment...")
        run_shell_command(plan_command)

        print("Applying the plan...")
        run_shell_command(apply_command)

    elif action == "destroy":
        print("Destroying the infrastructure...")
        run_shell_command(destroy_command)


def check_env(environment):
    if environment == "dev":
        print("Deploying artifacts to dev")
    elif environment == "preprod":
        print("Deploying artifacts to preprod")
    elif environment == "prod":
        print("Deploying artifacts to prod")
    else:
        print(
            f"Invalid environment: {environment}. Must be dev, preprod or prod"
        )
        sys.exit(1)


def deployment_profile(environment):
    if environment == "dev":
        profile = "aws-acct-training.AdministratorAccess"
    elif environment == "preprod":
        profile = "aws-acct-training-preprod.AdministratorAccess"
    elif environment == "prod":
        profile = "aws-acct-training-prod.AdministratorAccess"
    else:
        print("Invalid deployment: %s Must be dev, preprod or prod")
        sys.exit(1)
    return profile


def get_backend_bucket(profile=None, region=None):
    command = f"aws ssm get-parameter --name '/backend/s3_bucket' --query 'Parameter.Value' --output text"

    if profile and region:
        command += f" --region '{region}' --profile '{profile}'"

    result = subprocess.run(
        command, shell=True, check=True, capture_output=True, text=True
    )
    return result.stdout.strip()


def run_shell_command(command):
    print(f"Running command {command}")
    res = os.system(command)

    if res != 0:
        print(f"Command did not execute successfully")
        sys.exit(1)


if __name__ == "__main__":
    deploy()
