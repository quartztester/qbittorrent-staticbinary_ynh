#!/bin/bash

#=================================================
# COMMON FUNCTIONS AND VARS
#=================================================

# Reachability-censused I2P-only tracker list; opentracker.i2p.rocks deliberately excluded (clearnet bridge — announcing there would outproxy and leak the server IP).
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

# WebUI password hash is Qt QPasswordDigestor format: PBKDF2-HMAC-SHA512, 100000 iterations, "salt:derived" in base64.
render_qbt_config() {
    webui_pwd_hash="$(python3 - "$webui_password" <<'PY'
import base64, hashlib, os, sys
salt = os.urandom(16)
dk = hashlib.pbkdf2_hmac("sha512", sys.argv[1].encode(), salt, 100000)
print(base64.b64encode(salt).decode() + ":" + base64.b64encode(dk).decode())
PY
)"

    # YunoHost booleans arrive as 1/0 or true/false depending on the arg-serialization path; normalize.
    local anon="${anonymous:-true}"
    case "$(echo "$anon" | tr '[:upper:]' '[:lower:]')" in
        true|1|yes|on)
            # Safe: libtorrent's anonymous session suppresses DHT/PeX/LSD functionally (verified: zero UDP sockets / conntrack hits).
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

    # i2pd guide: tracker traffic goes through the router's HTTP proxy — that is what resolves *.i2p tracker names.
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

    # Session\AdditionalTrackers must be ONE line with literal \n separators; python writes it (env-var handoff, quoted heredoc, no shell interpolation).
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
# ACCOUNT-FREE I2P DISCOVERY: POSTMAN SEARCH PLUGIN (SEARCH-ONLY)
#=================================================
# SEARCH-ONLY discovery via the WebUI Search tab (bundled postman_i2p resolves .i2p via qbt's proxy env). RSS pre-registration retired: empty/throttled, Search supersedes. Idempotent.
ynh_enable_i2p_discovery() {
    ynh_script_progression "Enabling account-free I2P discovery (Postman search plugin)..."

    # search plugin subprocesses fetch through the session's misc proxy
    curl -sf -X POST \
        --data-urlencode 'json={"proxy_misc":true,"rss_processing_enabled":false}' \
        "http://127.0.0.1:$port/api/v2/app/setPreferences" >/dev/null || true
    # retire the legacy auto-registered feed if an older install has it
    curl -sf -X POST -d "path=Postman" \
        "http://127.0.0.1:$port/api/v2/rss/removeItem" >/dev/null || true

    # Only the I2P-native Postman engine is enabled; torrentfunk/torrentz mirror the clearnet catalog (unreachable from an I2P-only box), so installed but unticked.
    curl -sf -X POST -d "names=postman_i2p" -d "enable=true" \
        "http://127.0.0.1:$port/api/v2/search/enablePlugin" >/dev/null || true
    for eng in torrentfunk torrentz; do
        curl -sf -X POST -d "names=$eng" -d "enable=false" \
            "http://127.0.0.1:$port/api/v2/search/enablePlugin" >/dev/null || true
    done

    # qbt 5.x hard-codes engines to <conf>/data/nova3 (the Search\PluginsPath key no longer exists); pre-seed framework + engine from ../conf (scripts run with cwd = scripts/) or the settings archive on restore, so search works offline.
    local nova_src="" cand
    for cand in "../conf/nova3" "/etc/yunohost/apps/$app/conf/nova3"; do
        [ -d "$cand" ] && nova_src="$cand" && break
    done
    if [ -z "$nova_src" ]; then
        ynh_print_warn "nova3 framework tree not found; skipping search-plugin pre-seed"
    else
        local pl_dir="$data_dir/profile/qBittorrent/data/nova3"
        mkdir -p "$pl_dir/engines"
        cp -f "$nova_src/"*.py "$pl_dir/"
        cp -f "$nova_src/engines/"*.py "$pl_dir/engines/"
        find "$pl_dir" -name __pycache__ -type d -exec rm -rf {} + 2>/dev/null || true
        chown -R "$app:$app" "$pl_dir"
    fi

    # qbt 5.3 refuses search plugins below CPython 3.13 and Debian's system python is older: reuse a local standalone interpreter or unpack the pinned python-build-standalone tarball.
    local py=""
    for cand in "$install_dir/python/bin/python3.13" /usr/local/opt/python3.13/bin/python3.13; do
        [ -x "$cand" ] && py="$cand" && break
    done
    if [ -z "$py" ] && [ "$(uname -m)" = "x86_64" ]; then
        ynh_script_progression "Installing standalone CPython 3.13 for search plugins..."
        ynh_setup_source --source_id=py313 --dir="$install_dir" || true
        py="$install_dir/python/bin/python3.13"
        if [ -x "$py" ]; then
            # Soft: bundled engine is stdlib-only; pip failure (offline clearnet) must not disable search.
            "$py" -m pip install --quiet --disable-pip-version-check requests >/dev/null 2>&1 || true
        fi
    fi
    chown -R "$app:$app" "$install_dir/python" 2>/dev/null || true

    # systemd drop-in: HTTP_PROXY gives plugins .i2p resolution; qbt probes PATH for its search interpreter before Search\PythonPath, hence the shim.
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

    # qbt rewrites its conf at shutdown, so flip the Search keys while stopped, then restart once.
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
