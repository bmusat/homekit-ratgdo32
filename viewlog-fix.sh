UUID=$(uuidgen)
URL=$(curl -s "http://${1}/rest/events/subscribe?id=${UUID}&log=1&heartbeat=0")
curl -s "http://${1}/showlog"
curl -s -N "http://${1}${URL}?id=${UUID}" | awk '
  /^event: logger$/ { want=1; next }
  want { sub(/^data: /, ""); print; fflush(); want=0 }
'
