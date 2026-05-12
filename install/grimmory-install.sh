#!/usr/bin/env bash

# Copyright (c) 2021-2026 community-scripts ORG
# Author: MickLesk (CanbiZ)
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/grimmory-tools/grimmory
# Originally authored for BookLore by community-scripts; adapted for Grimmory by andersonimes.

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt install -y ffmpeg libarchive13
msg_ok "Installed Dependencies"

JAVA_VERSION="25" setup_java
NODE_VERSION="22" setup_nodejs
setup_mariadb
setup_yq
MARIADB_DB_NAME="booklore_db" MARIADB_DB_USER="booklore_user" MARIADB_DB_EXTRA_GRANTS="GRANT SELECT ON \`mysql\`.\`time_zone_name\`" setup_mariadb_db
fetch_and_deploy_gh_release "grimmory" "grimmory-tools/grimmory" "tarball"

if [[ ! -L /usr/lib/libarchive.so ]]; then
  ln -s /lib/x86_64-linux-gnu/libarchive.so /usr/lib/
fi

msg_info "Building Frontend"
cd /opt/grimmory/frontend
$STD npm install --force
$STD npm run build
msg_ok "Built Frontend"

msg_info "Creating Environment"
mkdir -p /opt/booklore_storage/{data,bookdrop}
cat <<EOF >/opt/booklore_storage/.env
DATABASE_URL=jdbc:mariadb://localhost:3306/${MARIADB_DB_NAME}
DATABASE_USERNAME=${MARIADB_DB_USER}
DATABASE_PASSWORD=${MARIADB_DB_PASS}

APP_PATH_CONFIG=/opt/booklore_storage/data
APP_BOOKDROP_FOLDER=/opt/booklore_storage/bookdrop
SERVER_PORT=6060
EOF
msg_ok "Created Environment"

msg_info "Building Backend"
cd /opt/grimmory/backend
APP_VERSION=$(get_latest_github_release "grimmory-tools/grimmory")
yq eval ".app.version = \"${APP_VERSION}\"" -i src/main/resources/application.yaml
$STD ./gradlew clean bootJar -PfrontendDistDir=/opt/grimmory/frontend/dist/grimmory/browser -x test --no-daemon
mkdir -p /opt/grimmory/dist
JAR_PATH=$(find /opt/grimmory/backend/build/libs -maxdepth 1 -type f -name "*.jar" ! -name "*plain*" | head -n1)
if [[ -z "$JAR_PATH" ]]; then
  msg_error "Backend JAR not found"
  exit 153
fi
cp "$JAR_PATH" /opt/grimmory/dist/app.jar
msg_ok "Built Backend"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/grimmory.service
[Unit]
Description=Grimmory Java Service
After=network.target mariadb.service

[Service]
Type=simple
User=root
WorkingDirectory=/opt/grimmory/dist
ExecStart=/usr/bin/java --enable-preview -XX:+UseG1GC -XX:+UseStringDeduplication -XX:+UseCompactObjectHeaders -XX:MaxRAMPercentage=75.0 -XX:+ExitOnOutOfMemoryError -jar /opt/grimmory/dist/app.jar
EnvironmentFile=/opt/booklore_storage/.env
SuccessExitStatus=143
TimeoutStopSec=10
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl enable -q --now grimmory
msg_ok "Created Service"

motd_ssh
customize
cleanup_lxc

cat > /usr/bin/update <<'UPDATE_EOF'
PHS_SILENT=1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/andersonimes/grimmory-proxmoxve/main/ct/grimmory.sh)"
UPDATE_EOF
chmod +x /usr/bin/update
