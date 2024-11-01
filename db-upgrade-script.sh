#!/bin/bash
set -e

# Make backups of the existing DBs
docker exec -it waldur-db pg_dumpall -U waldur > waldur_upgrade_backup.sql
docker exec -it keycloak-db pg_dumpall -U keycloak > keycloak_upgrade_backup.sql

# Shutdown containers
docker compose down

# Remove created volumes
mv pgsql "pgsql-old-$(date +'%Y.%m.%d_%H.%M.%S')"
docker volume rm waldur-docker-compose_keycloak_db

# Pull new images
docker compose pull

# Start the DB containers to load dump data
docker compose up -d waldur-db keycloak-db

# Wait for the container to initialize before using psql
sleep 4

# Restore DB contents
cat waldur_upgrade_backup.sql | docker exec -i waldur-db psql -U waldur
cat keycloak_upgrade_backup.sql | docker exec -i keycloak-db psql -U keycloak

# Create SCRAM tokens for existing users. This is needed if upgrading from older postgres versions.
export $(cat .env | grep "^POSTGRESQL_PASSWORD=" | xargs)
docker exec -it waldur-db psql -U waldur -c "ALTER USER waldur WITH PASSWORD '${POSTGRESQL_PASSWORD}';"
export $(cat .env | grep "^KEYCLOAK_POSTGRESQL_PASSWORD=" | xargs)
docker exec -it keycloak-db psql -U keycloak -c "ALTER USER keycloak WITH PASSWORD '${KEYCLOAK_POSTGRESQL_PASSWORD}';"

# Restart containers
docker compose up -d
