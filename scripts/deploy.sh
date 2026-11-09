
#!/bin/bash
set -Eeuo pipefail

# Required Jenkins environment variables
: "${AWS_DEFAULT_REGION:?Missing AWS region}"
: "${ASG_NAME:?Missing ASG name}"
: "${TARGET_GROUP_ARN:?Missing target group ARN}"
: "${ECR_IMAGE:?Missing new image URI}"
: "${ECR_REGISTRY:?Missing ECR registry}"
: "${SSH_USER:?Missing SSH username}"
: "${SSH_KEY:?Missing SSH key path}"

CONTAINER="vm-docker-app"
PORT=5000

# Discover healthy ASG instances
INSTANCES=$(aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names "$ASG_NAME" \
  --region "$AWS_DEFAULT_REGION" \
  --query 'AutoScalingGroups[0].Instances[?LifecycleState==`InService` && HealthStatus==`Healthy`].InstanceId' \
  --output text)

[[ -n "$INSTANCES" && "$INSTANCES" != "None" ]] || {
  echo "ERROR: No healthy ASG instances found."
  exit 1
}

for ID in $INSTANCES; do
  echo "Deploying to $ID"

  IP=$(aws ec2 describe-instances \
    --instance-ids "$ID" \
    --region "$AWS_DEFAULT_REGION" \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text)

  [[ -n "$IP" && "$IP" != "None" ]] || {
    echo "ERROR: Private IP unavailable for $ID."
    exit 1
  }

  # Remove instance from ALB traffic and drain connections
  aws elbv2 deregister-targets \
    --target-group-arn "$TARGET_GROUP_ARN" \
    --targets "Id=$ID" \
    --region "$AWS_DEFAULT_REGION"

  aws elbv2 wait target-deregistered \
    --target-group-arn "$TARGET_GROUP_ARN" \
    --targets "Id=$ID" \
    --region "$AWS_DEFAULT_REGION"

  # Deploy new image through SSH
  if ssh -i "$SSH_KEY" \
    -o BatchMode=yes \
    -o StrictHostKeyChecking=yes \
    "$SSH_USER@$IP" \
    "sudo bash -s -- '$ECR_IMAGE' '$ECR_REGISTRY' '$AWS_DEFAULT_REGION' '$CONTAINER' '$PORT'" <<'REMOTE'

set -Eeuo pipefail

NEW_IMAGE="$1"
REGISTRY="$2"
REGION="$3"
CONTAINER="$4"
PORT="$5"

STATE_DIR="/var/lib/vm-docker-deploy"
mkdir -p "$STATE_DIR"

# Save previous image before replacing it
OLD_IMAGE=$(docker inspect --format '{{.Config.Image}}' "$CONTAINER")
printf '%s\n' "$OLD_IMAGE" > "$STATE_DIR/previous-image"

# Pull and start new version
aws ecr get-login-password --region "$REGION" |
  docker login --username AWS --password-stdin "$REGISTRY"

docker pull "$NEW_IMAGE"
docker rm -f "$CONTAINER"

docker run -d \
  --name "$CONTAINER" \
  --restart unless-stopped \
  -p "$PORT:5000" \
  "$NEW_IMAGE"

# Verify the new application
for attempt in $(seq 1 10); do
  if curl -fsS "http://127.0.0.1:$PORT/health"; then
    echo "Deployment healthy."
    exit 0
  fi
  sleep 5
done

echo "New application failed health check."
exit 1

REMOTE
  then
    echo "Deployment succeeded on $ID."
  else
    echo "Deployment failed on $ID. Attempting rollback."

    if ./scripts/rollback.sh "$IP"; then
      echo "Rollback successful on $ID."
    else
      echo "CRITICAL: Rollback failed on $ID."
      echo "Instance remains deregistered from ALB."
    fi

    exit 1
  fi

  # Return only a successfully deployed instance to ALB
  aws elbv2 register-targets \
    --target-group-arn "$TARGET_GROUP_ARN" \
    --targets "Id=$ID" \
    --region "$AWS_DEFAULT_REGION"

  aws elbv2 wait target-in-service \
    --target-group-arn "$TARGET_GROUP_ARN" \
    --targets "Id=$ID" \
    --region "$AWS_DEFAULT_REGION"

  echo "$ID is healthy in ALB."
done

echo "Rolling deployment completed successfully."
