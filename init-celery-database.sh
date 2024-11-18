#!/bin/bash

set -e
set -u

function create_database() {
    local database=$1
    local username=$2
    echo "  Checking if database '$database' exists"

    DB_EXISTS=$(psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --tuples-only --no-align -c \
        "SELECT 1 FROM pg_database WHERE datname='$database';")

    if [[ $DB_EXISTS == "1" ]]; then
        echo "  Database '$database' exists. Skipping creation."
    else
        echo "  Creating database '$database' and granting privileges to '$username'"
        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
            CREATE DATABASE $database;
            GRANT ALL PRIVILEGES ON DATABASE $database TO $username;
EOSQL
        echo "$database DB created."
    fi
}

if [ -n "$POSTGRES_CELERY_DATABASE" ]; then
    echo "Creating additional DB, $POSTGRES_CELERY_DATABASE ."
    user=$POSTGRES_USER
    create_database "$POSTGRES_CELERY_DATABASE" "$user"
fi
