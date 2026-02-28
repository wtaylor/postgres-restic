#!/usr/bin/env bash

set -euo pipefail

for i in {1..5}; do
  export HOSTNAME_VAR="HOSTNAME_$i"
  export PGHOST_VAR="PGHOST_$i"
  export PGPASSWORD_VAR="PGPASSWORD_$i"
  export PGPORT_VAR="PGPORT_$i"
  export PGUSER_VAR="PGUSER_$i"
  export RESTIC_REPOSITORY_VAR="RESTIC_REPOSITORY_$i"

  export HOST="${!HOSTNAME_VAR:-${!PGHOST_VAR}}"
  export PGHOST="${!PGHOST_VAR}"
  export PGPASSWORD="${!PGPASSWORD_VAR}"
  export PGPORT="${!PGPORT_VAR:-5432}"
  export PGUSER="${!PGUSER_VAR:-postgres}"
  export RESTIC_REPOSITORY="${!RESTIC_REPOSITORY_VAR}"

  # No more databases.
  for var in PGHOST PGUSER RESTIC_REPOSITORY; do
    [[ -z "${!var}" ]] && {
      echo 'Finished backup successfully'
      exit 0
    }
  done

  if ! restic unlock; then
    restic init
  fi

  echo "Dumping database cluster $i: $PGUSER@$PGHOST:$PGPORT"

  # Wait for PostgreSQL to become available.
  COUNT=0
  until psql -l >/dev/null 2>&1; do
    if [[ "$COUNT" == 0 ]]; then
      echo "Waiting for PostgreSQL to become available..."
    fi
    ((COUNT += 1))
    sleep 1
  done
  if ((COUNT > 0)); then
    echo "Waited $COUNT seconds."
  fi

  mkdir -p "/pg_dump"

  # Dump individual databases directly to restic repository.
  DBLIST=$(psql -d postgres -q -t -c "SELECT datname FROM pg_database WHERE datname NOT IN ('postgres', 'rdsadmin', 'template0', 'template1')")
  for dbname in $DBLIST; do
    echo "Dumping database '$dbname'"
    pg_dump -Fc --file="/pg_dump/$dbname.dump" "$dbname"
  done

  echo "Sending database dumps to $RESTIC_REPOSITORY..."
  while ! restic backup "/pg_dump"; do
    echo "Sleeping for 10 seconds before retry..."
    sleep 10
  done

  echo "Finished sending database dumps to $RESTIC_REPOSITORY"

  rm -rf "/pg_dump"
done

echo 'Finished backup successfully'
