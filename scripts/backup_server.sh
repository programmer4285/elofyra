#!/usr/bin/env bash
#
# Weekly backup of the elofyra server to Backblaze B2 via restic.
#
#   dump immich db -> stop containers -> back up 5 paths -> start containers -> prune
#
# Run as root (writes /var/log, uses docker):  sudo ./scripts/backup_server.sh
#
set -euo pipefail

REPO_DIR="/home/eloquent/elofyra"
MOUNT="/mnt/alexandria"
LOG_FILE="/var/log/elofyra-backup.log"
EXCLUDE_FILE="${REPO_DIR}/restic/appdata_exclude"
DB_DUMP="${MOUNT}/appdata/immich/immich-database.sql"

SERVICES=(jellyfin navidrome filebrowser immich)
SOURCES=(appdata media music photos cloud)

FAILED=()

log() { echo "[$(date -Iseconds)] $*"; }

start_services() {
  log "==> Starting containers"
  for svc in "${SERVICES[@]}"; do
    if (cd "${REPO_DIR}/docker/${svc}" && docker compose up -d); then
      log "    ${svc} up"
    else
      log "    ERROR: ${svc} failed to start"
      FAILED+=("start:${svc}")
    fi
  done
}

# --- preflight -------------------------------------------------------------

if [[ ${EUID} -ne 0 ]]; then
  echo "ERROR: must be run as root (sudo ./scripts/backup_server.sh)" >&2
  exit 1
fi

# Overwrite the log each run; still print to the terminal for manual runs.
exec > >(tee "${LOG_FILE}") 2>&1

log "=== elofyra backup starting ==="

# The critical guard: if the disk is not mounted the source paths still exist as
# empty directories. Backing those up would produce empty snapshots, and after
# three weekly runs --keep-last 3 would prune away every good snapshot.
if ! mountpoint -q "${MOUNT}"; then
  log "ERROR: ${MOUNT} is not mounted. Aborting."
  exit 1
fi

if [[ ! -f "${REPO_DIR}/.env" ]]; then
  log "ERROR: ${REPO_DIR}/.env not found. Aborting."
  exit 1
fi
# shellcheck disable=SC1091
source "${REPO_DIR}/.env"

# --- dump immich's database (needs postgres running) -----------------------

log "==> Dumping Immich database"
# No -t: a tty would translate newlines to CRLF in the dump file.
# Written to .tmp first so a failed dump does not clobber last week's good one.
if docker exec immich_postgres \
     pg_dumpall --clean --if-exists --username=postgres > "${DB_DUMP}.tmp"; then
  mv "${DB_DUMP}.tmp" "${DB_DUMP}"
  log "    wrote ${DB_DUMP}"
else
  rm -f "${DB_DUMP}.tmp"
  log "    ERROR: pg_dumpall failed; falling back to the pgdata files"
  FAILED+=("pg_dumpall")
fi

# --- stop, back up, start --------------------------------------------------

# Safety net: bring services back even if the script dies mid-backup.
trap start_services EXIT

log "==> Stopping containers"
for svc in "${SERVICES[@]}"; do
  if (cd "${REPO_DIR}/docker/${svc}" && docker compose down); then
    log "    ${svc} down"
  else
    log "    ERROR: ${svc} failed to stop"
    FAILED+=("stop:${svc}")
  fi
done

for src in "${SOURCES[@]}"; do
  log "==> Backing up ${MOUNT}/${src}"
  if restic backup "${MOUNT}/${src}" --exclude-file "${EXCLUDE_FILE}"; then
    log "    ${src} ok"
  else
    log "    ERROR: ${src} failed"
    FAILED+=("backup:${src}")
  fi
done

start_services
trap - EXIT

# --- prune (after restart: it is the slow B2 operation and needs nothing down)

log "==> Pruning old snapshots (keep last 3 per path)"
if restic forget --keep-last 3 --prune; then
  log "    prune ok"
else
  log "    ERROR: forget/prune failed"
  FAILED+=("prune")
fi

# --- report ----------------------------------------------------------------

echo
if [[ ${#FAILED[@]} -gt 0 ]]; then
  log "=== FINISHED WITH ERRORS: ${FAILED[*]} ==="
  exit 1
fi

log "=== Backup complete ==="
