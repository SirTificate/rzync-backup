#!/bin/bash
set -uo pipefail

HOSTS_DIR="/backup/hosts"
KNOWN_HOSTS_FILE="$HOME/.ssh/known_hosts"

for hostdir in "$HOSTS_DIR"/*; do
    [[ -d "$hostdir" ]] || continue
    hostname=$(basename "$hostdir")

    echo $hostname
    conf_file="$hostdir/c/backup.conf"
    [[ -f "$conf_file" ]] || continue

    # Port auslesen (default 22)
    port="22"
    rsync_args=$(grep '^RSYNC_ADDITIONAL_ARGS=' "$conf_file" | cut -d\' -f2 || true)
    if [[ "$rsync_args" =~ -p[[:space:]]([0-9]+) ]]; then
        port="${BASH_REMATCH[1]}"
    fi

    echo $conf_file
    rsync_host=$(awk -F= '/^RSYNC_HOST=/ { gsub(/["'\'']/, "", $2); print $2 }' "$conf_file" || true)
    rsync_host="${rsync_host:-$hostname}"

    echo "[+] Scanning $rsync_host on port $port..."

#    # Temporär speichern und prüfen, ob Host schon in known_hosts steht
#    scan_output=$(ssh-keyscan -p "$port" -T 5 "$rsync_host" 2>/dev/null)

    if ! ssh-keygen -F "$rsync_host:$port" ; then
      ssh-keyscan -p "$port" -H "$rsync_host" >> ~/.ssh/known_hosts
      echo "    [✓] Fingerprint hinzugefügt für $rsync_host"
    fi


#    echo $scan_output
#    if [[ -z "$scan_output" ]]; then
#        echo "    [!] ERROR: No key found for $rsync_host:$port"
#        continue
#    fi
#
#    # Host-Eintrag in der Form: [hostname]:port
#    key_entry="[$rsync_host]:$port"
#
#    # Lösche evtl. alten Eintrag
#    ssh-keygen -R "$key_entry" &>/dev/null || true
#
#    # Füge neuen Fingerprint ein
#    echo "$scan_output" >> "$KNOWN_HOSTS_FILE"
done

echo "✔ Alle Hosts verarbeitet."
