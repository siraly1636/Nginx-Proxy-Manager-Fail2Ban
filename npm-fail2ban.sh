#!/bin/bash
set -e

MODE="$1"

DENYCONF_DEFAULT="/data/nginx/fail2ban/deny.conf"

install() {
  echo "=== Fail2Ban + NPM telepítés ==="
  echo

  read -rp "deny.conf útvonala [$DENYCONF_DEFAULT]: " DENYCONF
  DENYCONF="${DENYCONF:-$DENYCONF_DEFAULT}"
  DENYDIR=$(dirname "$DENYCONF")

  mkdir -p "$DENYDIR"
  mkdir -p /etc/fail2ban/{action.d,filter.d,jail.d}

  echo "# Fail2Ban global deny list" > "$DENYCONF"

  cat > /etc/fail2ban/action.d/npm-nginx-deny.conf <<EOF
[Definition]
actionban = echo "deny <ip>;" >> $DENYCONF && docker exec $NPM_CONTAINER nginx -s reload
actionunban = sed -i "\\|deny <ip>;|d" $DENYCONF && docker exec $NPM_CONTAINER nginx -s reload
EOF

  read -rp "Nginx Proxy Manager docker container neve (nginxproxymanager): " NPM_CONTAINER


# Casaos Filter + Jail

  read -rp "Létrehozzam a casaos-login jailt? (y/n): " CASAOS

  if [[ "$CASAOS" =~ ^[Yy]$ ]]; then
    echo "→ casaos-login filter + jail"
    read -rp "Figyelendő log fájl: " LOGPATH

    cat > /etc/fail2ban/filter.d/casaos-login.conf <<'EOF'
[Definition]
failregex = ^\[.*\]\s+-\s+400\s+400\s+-\s+POST\s+http\s+\S+\s+"\/v1\/users\/login".*\[Client <HOST>\]
ignoreregex =
EOF

    cat > /etc/fail2ban/jail.d/casaos-login.conf <<EOF
[casaos-login]
enabled  = true
filter   = casaos-login
logpath  = $LOGPATH
maxretry = 3
findtime = 10m
bantime  = 1h
action   = npm-nginx-deny
EOF
  fi


# HomeAssistent Filter + Jail

  read -rp "Létrehozzam a homeassistant-login jailt? (y/n): " HOMEASSISTANT

  if [[ "$HOMEASSISTANT" =~ ^[Yy]$ ]]; then
    echo "→ homeassistant-login filter + jail"
    read -rp "Figyelendő log fájl: " LOGPATH

    cat > /etc/fail2ban/filter.d/homeassistant-login.conf <<'EOF'
[Definition]
failregex = ^.*POST .*?/auth/login_flow.*\[Client <HOST>\].*$
ignoreregex =
EOF

    cat > /etc/fail2ban/jail.d/homeassistant-login.conf <<EOF
[homeassistant-login]
enabled  = true
filter   = homeassistant-login
logpath  = $LOGPATH
maxretry = 3
findtime = 10m
bantime  = 1h
action = npm-nginx-deny

EOF
  fi


# NextCloud Filter + Jail

  read -rp "Létrehozzam a nextcloud-login jailt? (y/n): " NEXTCLOUD

  if [[ "$NEXTCLOUD" =~ ^[Yy]$ ]]; then
    echo "→ nextcloud-login filter + jail"
    read -rp "Figyelendő log fájl: " LOGPATH

    cat > /etc/fail2ban/filter.d/nextcloud-login.conf <<'EOF'
[Definition]
failregex = ^.*POST http .* "/login".* \[Client <HOST>\].*$
ignoreregex =
EOF

    cat > /etc/fail2ban/jail.d/nextcloud-login.conf <<EOF
[nextcloud-login]
enabled  = true
filter   = nextcloud-login
logpath  = $LOGPATH
maxretry = 3
findtime = 10m
bantime  = 1h
action = npm-nginx-deny

EOF
  fi

  echo
  echo "Telepítés kész"
  echo
  echo "NPM Proxy Host → Advanced mező:"
  echo
  echo "real_ip_header X-Forwarded-For;"
  echo "include $DENYCONF;"
  echo
  echo "Fail2Ban újraindítása:"
  echo "systemctl restart fail2ban"
}

uninstall() {
  echo "=== Fail2Ban + NPM eltávolítás ==="

  rm -f /etc/fail2ban/action.d/npm-nginx-deny.conf
  rm -f /etc/fail2ban/filter.d/casaos-login.conf
  rm -f /etc/fail2ban/jail.d/casaos-login.conf

  rm -f /etc/fail2ban/filter.d/homeassistant-login.conf
  rm -f /etc/fail2ban/jail.d/homeassistant-login.conf

    rm -f /etc/fail2ban/filter.d/nextcloud-login.conf
  rm -f /etc/fail2ban/jail.d/nextcloud-login.conf

  systemctl restart fail2ban

  echo
  echo "deny.conf NEM lett törölve (szándékosan)"
  echo "Ha akarod manuálisan:"
  echo "rm -f $DENYCONF_DEFAULT"
  echo
  echo "Eltávolítás kész"
}

case "$MODE" in
  --install) install ;;
  --uninstall) uninstall ;;
  *)
    echo "Használat:"
    echo "  --install   → telepítés"
    echo "  --uninstall → eltávolítás"
    echo
    echo "bash -c "$(curl -fsSL https://raw.githubusercontent.com/siraly1636/Nginx-Proxy-Manager-Fail2Ban/refs/heads/main/npm-fail2ban.sh)" -s --install"
    exit 1
    ;;
esac
