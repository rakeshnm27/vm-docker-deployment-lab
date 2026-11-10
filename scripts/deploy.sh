
#!/usr/bin/env bash

set -Eeuo pipefail

# --------------------------------------------------
# Required Jenkins environment variables
# --------------------------------------------------

: "${AWS_DEFAULT_REGION:?Missing AWS region}"
: "${ASG_NAME:?Missing ASG name}"
: "${TARGET_GROUP_ARN:?Missing target group ARN}"
: "${ECR_IMAGE:?Missing new image URI}"
: "${ECR_REGISTRY:?Missing ECR registry}"
: "${SSH_USER:?Missing SSH username}"
: "${SSH_KEY:?Missing SSH key path}"

CONTAINER="vm-docker-app"
PORT=5000

SSH_OPTS=(
    -i "$SSH_KEY"
    -o BatchMode=yes
    -o ConnectTimeout=10
    -o ConnectionAttempts=1
    -o StrictHostKeyChecking=no
    -o UserKnownHostsFile=/dev/null
    -o LogLevel=ERROR
)

# --------------------------------------------------
# Validate SSH key
# --------------------------------------------------

if [[ ! -f "$SSH_KEY" || ! -r "$SSH_KEY" ]]; then
    echo "ERROR: SSH private key is missing or unreadable."
    exit 1
fi

# --------------------------------------------------
# Discover healthy EC2 instances in ASG
# --------------------------------------------------

echo "Discovering healthy ASG instances..."

INSTANCES=$(aws autoscaling describe-auto-scaling-groups \
    --auto-scaling-group-names "$ASG_NAME" \
    --region "$AWS_DEFAULT_REGION" \
    --query 'AutoScalingGroups[0].Instances[?LifecycleState==`InService` && HealthStatus==`Healthy`].InstanceId' \
    --output text)

if [[ -z "$INSTANCES" || "$INSTANCES" == "None" ]]; then
    echo "ERROR: No healthy ASG instances found."
    exit 1
fi

echo "Instances discovered: $INSTANCES"

# --------------------------------------------------
# Rolling deployment
# --------------------------------------------------

for ID in $INSTANCES; do

    echo "----------------------------------------"
    echo "Starting deployment on instance: $ID"
    echo "----------------------------------------"

    # --------------------------------------------------
    # Get private IP
    # --------------------------------------------------

    IP=$(aws ec2 describe-instances \
        --instance-ids "$ID" \
        --region "$AWS_DEFAULT_REGION" \
        --query 'Reservations[0].Instances[0].PrivateIpAddress' \
        --output text)

    if [[ -z "$IP" || "$IP" == "None" ]]; then
        echo "ERROR: Private IP unavailable for $ID."
        exit 1
    fi

    echo "Instance private IP: $IP"

    # --------------------------------------------------
    # SSH PREFLIGHT - BEFORE ALB DEREGISTRATION
    # --------------------------------------------------

    echo "Verifying SSH connectivity and authentication..."

    if ssh "${SSH_OPTS[@]}" \
        "$SSH_USER@$IP" \
        "hostname"; then

        echo "SSH preflight successful."

    else

        echo "ERROR: SSH preflight failed for $ID."
        echo "Instance remains registered with ALB."
        exit 1

    fi

    # --------------------------------------------------
    # Deregister from ALB
    # --------------------------------------------------

    echo "Deregistering $ID from ALB..."

    aws elbv2 deregister-targets \
        --target-group-arn "$TARGET_GROUP_ARN" \
        --targets "Id=$ID" \
        --region "$AWS_DEFAULT_REGION"

    aws elbv2 wait target-deregistered \
        --target-group-arn "$TARGET_GROUP_ARN" \
        --targets "Id=$ID" \
        --region "$AWS_DEFAULT_REGION"

    echo "Target successfully deregistered."

    # --------------------------------------------------
    # Prepare remote deployment command
    # --------------------------------------------------

    printf -v REMOTE_COMMAND \
        'sudo bash -s -- %q %q %q %q %q' \
        "$ECR_IMAGE" \
        "$ECR_REGISTRY" \
        "$AWS_DEFAULT_REGION" \
        "$CONTAINER" \
        "$PORT"

    # --------------------------------------------------
    # Deploy new Docker image through SSH
    # --------------------------------------------------

    if ssh "${SSH_OPTS[@]}" \
        "$SSH_USER@$IP" \
        "$REMOTE_COMMAND" <<'REMOTE'

set -Eeuo pipefail

NEW_IMAGE="$1"
REGISTRY="$2"
REGION="$3"
CONTAINER="$4"
PORT="$5"

STATE_DIR="/var/lib/vm-docker-deploy"

mkdir -p "$STATE_DIR"

# Save currently running image for rollback
OLD_IMAGE=$(docker inspect \
    --format '{{.Config.Image}}' "$CONTAINER")

printf '%s\n' "$OLD_IMAGE" > "$STATE_DIR/previous-image"

echo "Previous image: $OLD_IMAGE"
echo "New image: $NEW_IMAGE"

# Authenticate with Amazon ECR
aws ecr get-login-password --region "$REGION" |
    docker login \
        --username AWS \
        --password-stdin "$REGISTRY"

# Pull new image
docker pull "$NEW_IMAGE"

# Replace existing container
docker rm -f "$CONTAINER"

docker run -d \
    --name "$CONTAINER" \
    --restart unless-stopped \
    -p "$PORT:5000" \
    "$NEW_IMAGE"

# Application health check
for attempt in $(seq 1 10); do

    if curl -fsS "http://127.0.0.1:$PORT/health"; then
        echo
        echo "Deployment healthy."
        exit 0
    fi

    echo "Health check attempt $attempt failed."
    sleep 5

done

echo "New application failed health check."
exit 1

REMOTE

    then

        echo "Deployment succeeded on $ID."

    else

        # --------------------------------------------------
        # Rollback on deployment failure
        # --------------------------------------------------

        echo "Deployment failed on $ID."
        echo "Attempting rollback..."

        if bash ./scripts/rollback.sh "$IP"; then

            echo "Rollback successful on $ID."

            echo "Re-registering rolled-back instance with ALB..."

            aws elbv2 register-targets \
                --target-group-arn "$TARGET_GROUP_ARN" \
                --targets "Id=$ID" \
                --region "$AWS_DEFAULT_REGION"

            aws elbv2 wait target-in-service \
                --target-group-arn "$TARGET_GROUP_ARN" \
                --targets "Id=$ID" \
                --region "$AWS_DEFAULT_REGION"

            echo "Rolled-back instance is healthy in ALB."

        else

            echo "CRITICAL: Rollback failed on $ID."
            echo "Instance remains deregistered from ALB."

        fi

        exit 1

    fi

    # --------------------------------------------------
    # Register successfully deployed instance with ALB
    # --------------------------------------------------

    echo "Registering successfully deployed instance with ALB..."

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

# --------------------------------------------------
# Deployment completed
# --------------------------------------------------

echo "----------------------------------------"
echo "Rolling deployment completed successfully."
echo "Image deployed: $ECR_IMAGE"
echo "----------------------------------------"

