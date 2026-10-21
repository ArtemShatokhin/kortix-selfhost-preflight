#!/usr/bin/env bash
# kortix-selfhost-preflight
# Check a server BEFORE the first Kortix self-host start, so the failures the
# installer would hit later show up now.
set -uo pipefail

DOMAIN=""; INSTANCE="default"; FAIL=0
ok()   { printf '  ok    %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; FAIL=$((FAIL+1)); }
warn() { printf '  warn  %s\n' "$1"; }

while [ $# -gt 0 ]; do
  case "$1" in
    --domain) DOMAIN="$2"; shift 2 ;;
    --instance) INSTANCE="$2"; shift 2 ;;
    -h|--help) echo "usage: preflight.sh --domain kortix.example.com [--instance default]"; exit 0 ;;
    *) echo "unknown flag: $1" >&2; exit 2 ;;
  esac
done

echo "1. Docker Engine and the Compose plugin"
if command -v docker >/dev/null 2>&1; then
  ok "docker $(docker version --format '{{.Server.Version}}' 2>/dev/null || echo installed)"
  if docker compose version >/dev/null 2>&1; then ok "compose plugin present"
  else bad "the compose plugin is missing (docker compose version fails)"; fi
  if docker info >/dev/null 2>&1; then ok "daemon reachable as $(id -un)"
  else bad "the daemon is not reachable as $(id -un): add the user to the docker group and open a new shell"; fi
else
  bad "docker is not installed: the installer adds it on a bare Linux server"
fi

echo "2. DNS, before the first start"
if [ -z "$DOMAIN" ]; then
  warn "no --domain given: domain mode needs A or AAAA records for <domain> and api.<domain>"
else
  for host in "$DOMAIN" "api.$DOMAIN"; do
    if getent hosts "$host" >/dev/null 2>&1; then
      ok "$host resolves to $(getent hosts "$host" | awk '{print $1}' | head -1)"
    else
      bad "$host does not resolve: Caddy cannot get a certificate until it does"
    fi
  done
  if getent hosts "p.$DOMAIN" >/dev/null 2>&1; then ok "p.$DOMAIN resolves (preview origin)"
  else warn "p.$DOMAIN does not resolve: browser previews fall back to a path proxy and doctor fails"; fi
fi

echo "3. Ports 80 and 443"
if command -v ss >/dev/null 2>&1; then
  for port in 80 443; do
    if ss -ltn "sport = :$port" 2>/dev/null | grep -q LISTEN; then
      bad "port $port is already listening: stop the process that holds it before start"
    else
      ok "port $port free locally"
    fi
  done
else
  warn "ss not found: check ports 80 and 443 by hand"
fi

echo "4. Keys the instance cannot start without"
if [ -n "${PLATINUM_API_KEY:-}" ]; then ok "PLATINUM_API_KEY is set in this shell"
else warn "PLATINUM_API_KEY is not exported here: configure asks for it, and without it no session starts"; fi
warn "a model provider key is not part of the install: add it in the web app after the first sign-in"

echo "5. Instance directory"
DIR="$HOME/.config/kortix/self-host/$INSTANCE"
if [ -d "$DIR" ]; then
  ok "instance directory exists: $DIR"
  for f in docker-compose.yml .env Caddyfile updater.sh; do
    if [ -f "$DIR/$f" ]; then ok "  $f present"; else warn "  $f missing"; fi
  done
  if [ -f "$DIR/.env" ]; then
    if [ -n "$(grep '^KORTIX_DOMAIN=' "$DIR/.env" 2>/dev/null | cut -d= -f2-)" ]; then
      ok "KORTIX_DOMAIN is set in .env"
    else
      warn "KORTIX_DOMAIN is empty in .env: domain mode stays off and sessions cannot call back"
    fi
    if grep -q '^DISABLE_SIGNUP=true' "$DIR/.env" 2>/dev/null || grep -q '^EMAIL_URL=' "$DIR/.env" 2>/dev/null; then
      ok "sign-up is closed or email delivery is configured"
    else
      warn "sign-up is open: until EMAIL_URL or DISABLE_SIGNUP=true is set, anyone who reaches the instance can create a confirmed account"
    fi
  fi
else
  warn "no instance directory yet at $DIR: run the installer, then kortix self-host configure"
fi

echo
if [ "$FAIL" -eq 0 ]; then echo "preflight: 0 failures"; exit 0; fi
echo "preflight: $FAIL failure(s) to fix before start"; exit 1
