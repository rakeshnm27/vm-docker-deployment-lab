
#!/bin/bash

set -e

APP_PORT="${1:-5000}"
MAX_RETRIES=10
RETRY_INTERVAL=5

echo "Checking application health on port ${APP_PORT}..."

for attempt in $(seq 1 "$MAX_RETRIES"); do

    if curl -fsS "http://127.0.0.1:${APP_PORT}/health"; then
        echo
        echo "Application is healthy!"
        exit 0
    fi

    echo "Attempt ${attempt}/${MAX_RETRIES} failed."
    sleep "$RETRY_INTERVAL"

done

echo "Application health check failed!"
exit 1
