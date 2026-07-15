#!/usr/bin/env bash
# Load-test ratgdo's SSE subscription slots using isolated Docker containers.
#
# Usage:
#   ./tools/sse-load-test.sh start <host> [count]   # spin up N simulated clients (default 6)
#   ./tools/sse-load-test.sh sever <name>            # silently kill one client's network
#                                                       # (no TCP close sent - simulates a
#                                                       # phone dropping off WiFi mid-connection)
#   ./tools/sse-load-test.sh list                    # show running test containers
#   ./tools/sse-load-test.sh stop                    # tear down all test containers, then
#                                                       # wait 15s for connections to actually
#                                                       # close (Docker Desktop's VM networking
#                                                       # lags several seconds behind `docker rm`)
#
# Example:
#   ./tools/sse-load-test.sh start 192.168.168.180 6
#   ./tools/sse-load-test.sh list
#   ./tools/sse-load-test.sh sever ratgdo-load-3
#   # watch ratgdo's live log for "fail on fd ..., errno: 11" to start repeating
#   ./tools/sse-load-test.sh stop

set -euo pipefail

PREFIX="ratgdo-load"
IMAGE="curlimages/curl"

case "${1:-}" in
  start)
    HOST="${2:?usage: $0 start <host-or-ip> [count]}"
    COUNT="${3:-6}"
    for i in $(seq 1 "$COUNT"); do
      NAME="${PREFIX}-${i}"
      # Generate the UUID on the host (not inside the container) so we can print
      # it up front - lets you grep ratgdo's log for this exact string to know
      # precisely which container a given subscription/removal line belongs to,
      # without needing containers to have distinct source IPs.
      UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
      docker rm -f "$NAME" >/dev/null 2>&1 || true
      docker run -d --name "$NAME" -e UUID="$UUID" "$IMAGE" sh -c "
        URL=\$(curl -s \"http://${HOST}/rest/events/subscribe?id=\${UUID}\")
        case \"\$URL\" in
          /*) ;;
          *) echo \"subscribe rejected: \$URL\" >&2; exit 1 ;;
        esac
        exec curl -s -N \"http://${HOST}\${URL}?id=\${UUID}\"
      " >/dev/null
      echo "started $NAME  uuid=$UUID"
    done
    echo ""
    echo "Now check ratgdo's live log/status - you should see $COUNT new SSE subscriptions."
    echo "grep the log for the uuid above to identify which container a line belongs to."
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
    # Docker Desktop on Mac proxies container networking through a VM, and the
    # TCP close for a killed container's connection can take 10+ seconds to
    # actually reach the peer (observed 7-13s in testing) - well after `docker
    # rm` itself returns. Starting a new batch immediately can make ratgdo's
    # subscription table still show the previous batch as occupied. Wait it
    # out here so `stop` really means stopped before you run `start` again.
    echo "waiting 15s for connections to fully close (Docker Desktop networking lag)..."
    sleep 15
    ;;

  *)
    echo "Usage: $0 {start <host> [count]|sever <name>|list|stop}"
    exit 1
    ;;
esac
