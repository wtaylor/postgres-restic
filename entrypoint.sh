#!/usr/bin/env bash

set -eo pipefail

export DUMP_ROOT_VAR="DUMP_ROOT"
export DUMP_ROOT="${!DUMP_ROOT_VAR:-/pg_dump}"

mkdir -p "$DUMP_ROOT"

for i in {1..5}; do
  export PGHOST_VAR="PGHOST_$i"
  export PGPASSWORD_VAR="PGPASSWORD_$i"
  export PGPORT_VAR="PGPORT_$i"
  export PGUSER_VAR="PGUSER_$i"
  export RESTIC_REPOSITORY_VAR="RESTIC_REPOSITORY_$i"

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
  until psql -l; do
    if [[ "$COUNT" == 0 ]]; then
      echo "Waiting for PostgreSQL to become available..."
    fi
    ((COUNT += 1))
    sleep 1
  done
  if ((COUNT > 0)); then
    echo "Waited $COUNT seconds."
  fi

  # Dump individual databases directly to restic repository.
  DBLIST=$(psql -d postgres -q -t -c "SELECT datname FROM pg_database WHERE datname NOT IN ('postgres', 'rdsadmin', 'template0', 'template1')")
  for dbname in $DBLIST; do
    echo "Dumping database '$dbname'"
    pg_dump -Fc --file="$DUMP_ROOT/$dbname.dump" "$dbname"
  done

  echo "Sending database dumps to $RESTIC_REPOSITORY..."
  while ! restic backup "$DUMP_ROOT"; do
    echo "Sleeping for 10 seconds before retry..."
    sleep 10
  done

  echo "Finished sending database dumps to $RESTIC_REPOSITORY"

  rm -rf "$DUMP_ROOT/*"
done

echo 'Finished backup successfully'
