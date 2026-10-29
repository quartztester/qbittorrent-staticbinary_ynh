#!/bin/bash

#=================================================
# COMMON FUNCTIONS AND VARS
#=================================================

# I2P trackers (merged: docs.i2pd.website qBittorrent guide +
# ngosang/trackerslist trackers_all_i2p.txt, deduped by host:port).
# Refresh source: https://raw.githubusercontent.com/ngosang/trackerslist/master/trackers_all_i2p.txt
I2P_TRACKERS=$(cat <<'EOF'
http://btrackrqkjp6kgelov5a3uxisis77ofxqt5nvy5hvvtoybjpmq4q.b32.i2p/announce
http://freetracker.i2p:7331/announce
http://nyaaplus.i2p:80/announce
http://opentracker.dg2.i2p:80/a
http://opentracker.eeptorrent.i2p:80/a
http://opentracker.fattydove.i2p:80/a
http://opentracker.r4sas.i2p:80/a
http://opentracker.simp.i2p:80/a
http://opentracker.skank.i2p:80/a
http://qimlze77z7w32lx2ntnwkuqslrzlsqy7774v3urueuarafyqik5a.b32.i2p:80/a
http://sigmatracker.i2p:80/a
http://tracker.insulaocculta.i2p/a
http://tracker.nyaa2p.i2p:80/announce
http://yet-another-public-tracker.i2p/announce
udp://opentracker.simp.i2p:6969/a
udp://opentracker.skank.i2p:6969/a
http://tracker2.postman.i2p/announce.php
http://opentracker-actix.i2p/announce
http://opentracker.bt.i2p/a
http://vern.i2p:6969/announce
http://atia.i2p/announce
http://omitracker.i2p/announce
http://psa.i2p/a
EOF
)

# Render $data_dir/profile/qBittorrent/config/qBittorrent.conf from the
# conf/qBittorrent.conf template, deriving the WebUI PBKDF2 hash from the
# stored webui_password setting (Qt QPasswordDigestor: PBKDF2-HMAC-SHA512,
# 100000 iterations, "salt:derived" in base64).
render_qbt_config() {
    webui_pwd_hash="$(python3 - "$webui_password" <<'PY'
import base64, hashlib, os, sys
salt = os.urandom(16)
dk = hashlib.pbkdf2_hmac("sha512", sys.argv[1].encode(), salt, 100000)
print(base64.b64encode(salt).decode() + ":" + base64.b64encode(dk).decode())
PY
)"

    # Anonymous / I2P-only posture: no clearnet peer discovery at all.
    # YunoHost booleans may arrive as 1/0 or true/false depending on the
    # arg-serialization path, so normalize.
    local anon="${anonymous:-true}"
    case "$(echo "$anon" | tr '[:upper:]' '[:lower:]')" in
        true|1|yes|on)
            anonymous="true"; dht="false"; lsd="false"; pex="false"
            # i2pd guide: bind everything to loopback so nothing leaks
            net_interface="lo"; net_interface_address="127.0.0.1" ;;
        *)
            anonymous="false"; dht="true"; lsd="true"; pex="true"
            net_interface=""; net_interface_address="" ;;
    esac

    i2p_enabled="${i2p_enabled:-true}"
    i2p_sam_host="${i2p_sam_host:-127.0.0.1}"
    i2p_sam_port="${i2p_sam_port:-7656}"
    torrent_port="${torrent_port:-6881}"

    # i2pd guide: route tracker traffic through the router's HTTP proxy —
    # this is what resolves *.i2p tracker names at all. Only with I2P on.
    http_proxy_host="${http_proxy_host:-127.0.0.1}"
    http_proxy_port="${http_proxy_port:-4447}"
    if [ "$i2p_enabled" = "true" ]; then
        proxy_type="HTTP"
    else
        proxy_type=""
    fi

    add_trackers_enabled="${add_trackers_enabled:-true}"

    mkdir -p "$data_dir/profile/qBittorrent/config" "$data_dir/downloads"
    ynh_config_add --template="qBittorrent.conf" \
        --destination="$data_dir/profile/qBittorrent/config/qBittorrent.conf"

    # Session\AdditionalTrackers is ONE line with literal \n separators;
    # written through python (env-var handoff, quoted heredoc: no shell
    # interpolation anywhere).
    export I2P_TRACKERS
    python3 - "$data_dir/profile/qBittorrent/config/qBittorrent.conf" <<'PY'
import os, sys
path = sys.argv[1]
trackers = os.environ.get("I2P_TRACKERS", "").strip().replace('"', "")
line = "Session\\AdditionalTrackers=" + trackers.replace("\n", "\\n")
out, inserted = [], False
for l in open(path):
    if l.startswith("Session\\AdditionalTrackers="):
        continue
    out.append(l)
    if not inserted and l.startswith("Session\\AddTrackersEnabled="):
        out.append(line + "\n")
        inserted = True
open(path, "w").writelines(out)
PY

    chown -R "$app:$app" "$data_dir/profile" "$data_dir/downloads"
    chmod 600 "$data_dir/profile/qBittorrent/config/qBittorrent.conf"
}
