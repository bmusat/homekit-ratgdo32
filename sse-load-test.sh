#!/usr/bin/env bash
# Load-test ratgdo's SSE subscription slots using isolated Docker containers.
#
# Usage:
#   ./sse-load-test.sh start <host> [count]   # spin up N simulated clients (default 6)
#   ./sse-load-test.sh sever <name>            # silently kill one client's network
#                                               # (no TCP close sent - simulates a
#                                               # phone dropping off WiFi mid-connection)
#   ./sse-load-test.sh list                    # show running test containers
#   ./sse-load-test.sh stop                    # tear down all test containers
#
# Example:
#   ./sse-load-test.sh start 192.168.168.180 6
#   ./sse-load-test.sh list
#   ./sse-load-test.sh sever ratgdo-load-3
#   # watch ratgdo's live log for "fail on fd ..., errno: 11" to start repeating
#   ./sse-load-test.sh stop

set -euo pipefail

PREFIX="ratgdo-load"
IMAGE="curlimages/curl"

case "${1:-}" in
  start)
    HOST="${2:?usage: $0 start <host-or-ip> [count]}"
    COUNT="${3:-6}"
    for i in $(seq 1 "$COUNT"); do
      NAME="${PREFIX}-${i}"
      docker rm -f "$NAME" >/dev/null 2>&1 || true
      docker run -d --name "$NAME" "$IMAGE" sh -c "
        UUID=\$(cat /proc/sys/kernel/random/uuid)
        URL=\$(curl -s \"http://${HOST}/rest/events/subscribe?id=\${UUID}\")
        exec curl -s -N \"http://${HOST}\${URL}?id=\${UUID}\"
      " >/dev/null
      echo "started $NAME"
    done
    echo ""
    echo "Now check ratgdo's live log/status - you should see $COUNT new SSE subscriptions."
    ;;

  sever)
    NAME="${2:?usage: $0 sever <container-name>}"
    # Disconnecting the container from its network yanks the interface out from
    # under the running curl process - no FIN/RST is ever sent, unlike a normal
    # stop/kill. This is what actually reproduces a silently-dead connection.
    docker network disconnect bridge "$NAME"
    echo "severed network for $NAME (process still running, unaware)"
    ;;

  list)
    docker ps --filter "name=${PREFIX}" --format "table {{.Names}}\t{{.Status}}"
    ;;

  stop)
    docker rm -f $(docker ps -aq --filter "name=${PREFIX}") 2>/dev/null || echo "nothing to stop"
    ;;

  *)
    echo "Usage: $0 {start <host> [count]|sever <name>|list|stop}"
    exit 1
    ;;
esac
