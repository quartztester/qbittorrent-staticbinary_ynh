#!/bin/bash

#=================================================
# COMMON FUNCTIONS AND VARS
#=================================================

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
            anonymous="true"; dht="false"; lsd="false"; pex="false" ;;
        *)
            anonymous="false"; dht="true"; lsd="true"; pex="true" ;;
    esac

    i2p_enabled="${i2p_enabled:-true}"
    i2p_sam_host="${i2p_sam_host:-127.0.0.1}"
    i2p_sam_port="${i2p_sam_port:-7656}"
    torrent_port="${torrent_port:-6881}"

    mkdir -p "$data_dir/profile/qBittorrent/config" "$data_dir/downloads"
    ynh_config_add --template="qBittorrent.conf" \
        --destination="$data_dir/profile/qBittorrent/config/qBittorrent.conf"
    chown -R "$app:$app" "$data_dir/profile" "$data_dir/downloads"
    chmod 600 "$data_dir/profile/qBittorrent/config/qBittorrent.conf"
}
