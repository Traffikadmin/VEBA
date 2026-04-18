#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
#  bootstrap.sh – One-shot CloudFormation deployment for the full CI/CD stack
#
#  Usage:
#    ./scripts/bootstrap.sh \
#      --app-name      veba \
#      --region        us-west-1 \
#      --github-owner  YOUR_GITHUB_USERNAME \
#      --github-repo   YOUR_REPO_NAME \
#      --connection-arn arn:aws:codestar-connections:us-west-1:ACCOUNT_ID:connection/YOUR_ID
#
#  Prerequisites:
#    - AWS CLI v2 configured (aws configure)
#    - IAM permissions: CloudFormation, ECR, ECS, CodePipeline, CodeBuild, IAM, S3
#    - A CodeStar Connection to GitHub (create in AWS Console first)
#    - Secrets seeded: run ./scripts/create-secrets.sh first
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

APP_NAME="veba"
REGION="us-west-1"
GITHUB_OWNER=""
GITHUB_REPO=""
CONNECTION_ARN=""
CONTAINER_NAME="veba"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFN_DIR="$SCRIPT_DIR/../cloudformation"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-name)       APP_NAME="$2";       shift 2 ;;
    --region)         REGION="$2";         shift 2 ;;
    --github-owner)   GITHUB_OWNER="$2";   shift 2 ;;
    --github-repo)    GITHUB_REPO="$2";    shift 2 ;;
    --connection-arn) CONNECTION_ARN="$2"; shift 2 ;;
    --container-name) CONTAINER_NAME="$2"; shift 2 ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

if [[ -z "$GITHUB_OWNER" || -z "$GITHUB_REPO" || -z "$CONNECTION_ARN" ]]; then
  echo "ERROR: --github-owner, --github-repo, and --connection-arn are required."
  exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --region "$REGION")
echo ""
echo "========================================================"
echo " Bootstrap: $APP_NAME"
echo " Account:   $ACCOUNT_ID"
echo " Region:    $REGION"
echo " GitHub:    $GITHUB_OWNER/$GITHUB_REPO"
echo "========================================================"
echo ""

deploy_stack() {
  local stack_name="$1"
  local template="$2"
  shift 2
  local params=("$@")

  echo "──────────────────────────────────────────────────────"
  echo "Deploying stack: $stack_name"

  aws cloudformation deploy \
    --stack-name "$stack_name" \
    --template-file "$template" \
    --parameter-overrides "${params[@]}" \
    --capabilities CAPABILITY_NAMED_IAM \
    --region "$REGION" \
    --no-fail-on-empty-changeset

  echo "✔ $stack_name deployed."
  echo ""
}

# Stack 1: ECR + IAM + S3 artifacts (deploy once)
deploy_stack \
  "${APP_NAME}-foundations" \
  "$CFN_DIR/01-foundations.yml" \
  "AppName=$APP_NAME"

# Stack 2: VPC + ALB + ECS cluster (dev only)
deploy_stack \
  "${APP_NAME}-cluster-dev" \
  "$CFN_DIR/02-ecs-cluster.yml" \
  "AppName=$APP_NAME" \
  "EnvName=dev"

# Stack 3: CodePipeline (dev only)
deploy_stack \
  "${APP_NAME}-pipeline-dev" \
  "$CFN_DIR/03-pipeline.yml" \
  "AppName=$APP_NAME" \
  "EnvName=dev" \
  "GitHubOwner=$GITHUB_OWNER" \
  "GitHubRepo=$GITHUB_REPO" \
  "CodeStarConnectionArn=$CONNECTION_ARN" \
  "ContainerName=$CONTAINER_NAME"

echo ""
echo "========================================================"
echo " Deployment complete! ALB endpoint:"
echo "========================================================"
DNS=$(aws cloudformation describe-stacks \
  --stack-name "${APP_NAME}-cluster-dev" \
  --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='ALBDNSName'].OutputValue" \
  --output text 2>/dev/null || echo "(not yet available)")
echo "  dev → http://$DNS"
echo ""
echo "Next steps:"
echo "  1. Push to 'dev' branch to trigger the first pipeline run."
echo "  2. Watch progress: AWS Console → CodePipeline."
echo "  3. Update real DB passwords in Secrets Manager."
echo "  4. Point Route 53 / DNS at the ALB endpoints above."
echo ""
