
#!/bin/bash
set -Eeuo pipefail

INSTANCE_IP="${1:?Usage: rollback.sh PRIVATE_IP}"

: "${SSH_USER:?Missing SSH username}"
: "${SSH_KEY:?Missing SSH key path}"

ssh -i "$SSH_KEY" \
  -o BatchMode=yes \
  -o StrictHostKeyChecking=yes \
  "$SSH_USER@$INSTANCE_IP" \
  'sudo bash -s' <<'REMOTE'

set -Eeuo pipefail

CONTAINER="vm-docker-app"
PORT=5000
PREVIOUS_FILE="/var/lib/vm-docker-deploy/previous-image"

if [[ ! -s "$PREVIOUS_FILE" ]]; then
  echo "No previous image available for rollback."
  exit 1
fi

OLD_IMAGE=$(cat "$PREVIOUS_FILE")

echo "Restoring $OLD_IMAGE"

docker pull "$OLD_IMAGE"
docker rm -f "$CONTAINER" || true

docker run -d \
  --name "$CONTAINER" \
  --restart unless-stopped \
  -p "$PORT:5000" \
  "$OLD_IMAGE"

for attempt in $(seq 1 10); do
  if curl -fsS "http://127.0.0.1:$PORT/health"; then
    echo "Rollback successful."
    exit 0
  fi
  sleep 5
done

echo "Rollback health check failed."
exit 1

REMOTE
