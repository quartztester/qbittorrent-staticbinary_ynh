#!/bin/bash

#=================================================
# COMMON FUNCTIONS AND VARS
#=================================================

# I2P trackers. Reachability census 2026-10-29 via the box's I2P HTTP
# proxy: entries answer HTTP in any form (bencode, tracker-side error
# page, even empty opentracker body) = alive; name-unresolvable /
# proxy-refused / timeout = dropped. Removed this pass: nyaaplus,
# opentracker.eeptorrent, opentracker.simp (+udp), qimlz..b32, sigma,
# tracker.nyaa2p, opentracker-actix (host gone; dg2 is zzzot's vanity),
# vern, atia, omitracker, psa.  Deliberately excluded:
# opentracker.i2p.rocks (clearnet bridge — announcing there would
# outproxy and expose the server IP, against the I2P-only policy).
I2P_TRACKERS=$(cat <<'EOF'
http://tracker2.postman.i2p/announce.php
http://w7tpbzncbcocrqtwwm3nezhnnsw4ozadvi2hmvzdhrqzfxfum7wa.b32.i2p/a
http://btrackrqkjp6kgelov5a3uxisis77ofxqt5nvy5hvvtoybjpmq4q.b32.i2p/announce
http://yet-another-public-tracker.i2p/announce
http://freetracker.i2p:7331/announce
http://opentracker.dg2.i2p:80/a
http://opentracker.fattydove.i2p:80/a
http://opentracker.skank.i2p:80/a
http://opentracker.r4sas.i2p:80/a
http://opentracker.bt.i2p/a
http://tracker.insulaocculta.i2p/a
udp://opentracker.skank.i2p:6969/a
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
            # Checkboxes on by default per user preference; libtorrent's
            # anonymous session suppresses DHT/PeX/LSD functionally, so this
            # is leak-free (verified 2026-10-29: zero UDP sockets, zero
            # conntrack hits with anonymous on).
            anonymous="true"; dht="true"; lsd="true"; pex="true"
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

#=================================================
# Account-free I2P discovery: Postman RSS feed + search plugin
#=================================================
# tracker2.postman.i2p is where the live I2P swarms actually are.
# Two zero-signup channels, both routed through the router's HTTP proxy:
#   * WebUI RSS tab  -> feed fetched by qbt's own RSS engine (proxy_rss)
#   * WebUI Search tab -> bundled postman_i2p.py plugin; its python
#     subprocess resolves .i2p via HTTP_PROXY injected by a drop-in.
# Safe to re-run (idempotent).
ynh_enable_i2p_discovery() {
    ynh_script_progression "Enabling account-free I2P discovery (Postman RSS + search plugin)..."

    # --- RSS ---
    curl -sf -X POST \
        --data-urlencode 'json={"proxy_rss":true,"proxy_misc":true,"rss_processing_enabled":true}' \
        "http://127.0.0.1:$port/api/v2/app/setPreferences" >/dev/null || true
    curl -sf -X POST \
        --data-urlencode "path=Postman" \
        --data-urlencode "url=http://tracker2.postman.i2p/?view=RSS" \
        "http://127.0.0.1:$port/api/v2/rss/addFeed" >/dev/null || true

    # --- nova3 search framework + bundled postman_i2p engine ---
    # qbt 5.x hard-codes its engine location to <conf>/data/nova3 (the
    # Search/PluginsPath key no longer exists). On an online boot qbt
    # self-downloads the framework there; we pre-seed framework + our
    # engine so it also works offline and ships discovery out-of-box.
    local pl_dir="$data_dir/profile/qBittorrent/data/nova3"
    mkdir -p "$pl_dir/engines"
    cp -f "$install_dir/conf/nova3/"*.py "$pl_dir/"
    cp -f "$install_dir/conf/nova3/engines/"*.py "$pl_dir/engines/"
    chown -R "$app:$app" "$pl_dir"

    # --- Python >= 3.13 for qBittorrent's search subsystem ---
    # qbt 5.3 refuses to run search plugins below CPython 3.13; Debian's
    # system python is older. Reuse a local standalone interpreter if one
    # exists, otherwise unpack the pinned python-build-standalone tarball
    # into the install dir (same self-contained spirit as the static
    # qbittorrent-nox binary) and pip-install 'requests' into it.
    local py=""
    for cand in "$install_dir/python/bin/python3.13" /usr/local/opt/python3.13/bin/python3.13; do
        [ -x "$cand" ] && py="$cand" && break
    done
    if [ -z "$py" ] && [ "$(uname -m)" = "x86_64" ]; then
        ynh_script_progression "Installing standalone CPython 3.13 for search plugins..."
        ynh_setup_source --source_id=py313 --dir="$install_dir" || true
        py="$install_dir/python/bin/python3.13"
        if [ -x "$py" ]; then
            # soft: the bundled engine uses stdlib-only helpers; pip
            # failures (offline clearnet) must not disable search
            "$py" -m pip install --quiet --disable-pip-version-check requests >/dev/null 2>&1 || true
        fi
    fi
    chown -R "$app:$app" "$install_dir/python" 2>/dev/null || true

    # --- drop-in: .i2p name resolution (HTTP_PROXY) + shim python on PATH
    #     (qbt probes PATH for its search interpreter before applying
    #      Search\PythonPath, so the shim is what it actually finds) ---
    local px="${http_proxy_port:-4447}"
    rm -f "/etc/systemd/system/$app.service.d/i2p-proxy-env.conf" \
          "/etc/systemd/system/$app.service.d/i2p-search-python.conf"
    local shim=""
    if [ -n "$py" ]; then
        shim="$install_dir/python-shim"
        mkdir -p "$shim"
        ln -sf "$py" "$shim/python3"
    fi
    if [ -n "$shim" ]; then
        cat > "/etc/systemd/system/$app.service.d/i2p-search.conf" <<EOF
[Service]
Environment=HTTP_PROXY=http://127.0.0.1:$px
Environment=PATH=$shim:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
EOF
    else
        cat > "/etc/systemd/system/$app.service.d/i2p-search.conf" <<EOF
[Service]
Environment=HTTP_PROXY=http://127.0.0.1:$px
EOF
    fi

    # --- enable the search subsystem (qbt rewrites its conf at shutdown,
    #     so flip it while stopped, then restart once) ---
    local conf="$data_dir/profile/qBittorrent/config/qBittorrent.conf"
    if [ -n "$py" ] && ! grep -q '^Search\\Enabled=true' "$conf" 2>/dev/null; then
        ynh_systemctl --service="$app" --action="stop"
        sed -i '/^Search\\/d' "$conf"
        # keys must live in [Application] — qbt ignores them elsewhere
        awk -v p="$pl_dir" -v py="$py" '/^\[Application\]/{print; print "Search\\Enabled=true"; print "Search\\PluginsPath=" p; print "Search\\PythonPath=" py; next}1' "$conf" > "$conf.tmp" \
            && mv "$conf.tmp" "$conf"
        chown "$app:$app" "$conf"
        systemctl daemon-reload
        ynh_systemctl --service="$app" --action="start"
        for i in $(seq 1 30); do
            curl -sf "http://127.0.0.1:$port/api/v2/app/version" >/dev/null && break
            sleep 1
        done
    else
        systemctl daemon-reload
    fi
}
