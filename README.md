# Waldur Docker-compose deployment

## Prerequisites

- at least 8GB RAM on Docker Host to run all containers
- Docker v1.13+

## Prepare environment

```bash
# clone repo
git clone https://github.com/waldur/waldur-docker-compose.git
cd waldur-docker-compose
# setup settings
cp .env.example .env
```

## Booting up

```bash
# start containers
docker compose up -d

# verify
docker compose ps
docker exec -t waldur-mastermind-worker status

# Create user
docker exec -t waldur-mastermind-worker waldur createstaffuser -u admin -p password -e admin@example.com

# Create demo categories for OpenStack: Virtual Private Cloud, VMs and Storage
docker exec -t waldur-mastermind-worker waldur load_categories vpc vm storage
```

Waldur HomePort will be accessible on [https://localhost](https://localhost).
API will listen on [https://localhost/api](https://localhost/api).

Healthcheck can be accessed on [https://localhost/health-check](https://localhost/health-check).

Tearing down and cleaning up:

```bash
docker compose down
```

## Logs

Logs emitted by the containers are collected and saved in the `waldur_logs` folder. You can change the location by
editing environment variable (`.env`) and updating `LOG_FOLDER` value.

## Known issues

When Waldur is launched for the first time, it applies initial database migrations.
It means that you may need to wait few minutes until these migrations are applied.
Otherwise you may observe HTTP error 500 rendered by REST API server.
This issue would be resolved after upgrade to [Docker Compose 1.29](https://docs.docker.com/compose/release-notes/#1290).

To use a custom script offering type, it should be possible to connect to `/var/run/docker.sock` from
within the Waldur containers. If you are getting a permission denied error in logs, try setting more
open permissions, for example, `chmod 666 /var/run/docker.sock`. Note that this is not a secure
setup, so make sure you understand what you are doing.

## Upgrading Waldur

```bash
docker compose pull
docker compose restart
```

## Upgrade Instructions for PostgreSQL Images

### Upgrade Script

To simplify the upgrade process, an upgrade script `db-upgrade-script.sh` is included in the root directory, and can be used to automate the upgrade process.

#### Usage Instructions

1. **Ensure the script has execution permissions**:

   ```bash
   chmod +x db-upgrade-script.sh
    ```

2. **Update the `WALDUR_POSTGRES_IMAGE_TAG` and `KEYCLOAK_POSTGRES_IMAGE_TAG` in the `.env` file to the desired versions.**:

    ```sh
    WALDUR_POSTGRES_IMAGE_TAG=<your_version>
    KEYCLOAK_POSTGRES_IMAGE_TAG=<your_version>
    ```

3. **Run the sript**:

   ```bash
   ./db-upgrade-script.sh
    ```

### Upgrade Prerequisites

- Backup existing data (if needed).

#### Backup Commands

You can back up the database using `pg_dumpall`.

**For Waldur DB:**

```bash
docker exec -it waldur-db pg_dumpall -U waldur > /path/to/backup/waldur_upgrade_backup.sql
```

**For Keycloak DB:**

```bash
docker exec -it keycloak-db pg_dumpall -U keycloak > /path/to/backup/keycloak_upgrade_backup.sql
```

**Shut down containers:**

```bash
docker compose down
```

> **Note:**
> Before upgrading PostgreSQL, please delete the `pgsql` folder within the project directory if it exists, as well as the `keycloak_db` docker volume if it exists.
> These were created with the previous PostgreSQL version, and they will be recreated with docker compose during upgrade.
>
> You can remove the `pgsql` folder by running:
>
> ```bash
> sudo rm -r pgsql/
> ```
>
>
> To remove the `keycloak_db` volume, run:
>
>```bash
> docker volume rm waldur-docker-compose_keycloak_db
>```
>
> **Warning**: This action will delete your existing PostgreSQL data. Ensure it is backed up before proceeding.

### Upgrade Steps

1. **Update PostgreSQL Versions**

    Update the `WALDUR_POSTGRES_IMAGE_TAG` and `KEYCLOAK_POSTGRES_IMAGE_TAG` in the `.env` file to the required versions.

    ```sh
    WALDUR_POSTGRES_IMAGE_TAG=<your_version>
    KEYCLOAK_POSTGRES_IMAGE_TAG=<your_version>
    ```

2. **Pull the New Images**

    Pull the new PostgreSQL images:

    ```bash
    docker compose pull
    ```

3. **Optional: Restore Data** *(if backups have been made)*

    Start the database containers to load the dump data:

    ```bash
    docker compose up -d waldur-db keycloak-db
    ```

    Restore the contents of the database from the dump file:

    **For Waldur DB:**

    ```bash
    cat waldur_upgrade_backup.sql | docker exec -i waldur-db psql -U waldur
    ```

    **For Keycloak DB:**

    ```bash
    cat keycloak_upgrade_backup.sql | docker exec -i keycloak-db psql -U keycloak
    ```

    **Post-update steps**

    If the new psql version is later than 14, you need to create SCRAM tokens for the existing users.
    For this, run the following lines, which will automatically create necessary tokens for the users.

    ```bash
    export $(cat .env | grep "^POSTGRESQL_PASSWORD=" | xargs)
    docker exec -it waldur-db psql -U waldur -c "ALTER USER waldur WITH PASSWORD '${POSTGRESQL_PASSWORD}';"
    export $(cat .env | grep "^KEYCLOAK_POSTGRESQL_PASSWORD=" | xargs)
    docker exec -it keycloak-db psql -U keycloak -c "ALTER USER keycloak WITH PASSWORD '${KEYCLOAK_POSTGRESQL_PASSWORD}';"
    ```

4. **Start containers**

    Start all of the containers:

    ```bash
    docker compose up -d
    ```

5. **Verify the Upgrade**

    Verify the containers are running with the new PostgreSQL version:

    ```bash
    docker ps -a
    ```

    Check container logs for errors:

    ```bash
    docker logs waldur-db
    docker logs keycloak-db
    ```

## Using TLS

This setup supports following types of SSL certificates:

- Email - set environment variable TLS to your email to register Let's Encrypt account and get free automatic SSL certificates.

Example:

```bash
TLS=my@email.com
```

- Internal - set environment variable TLS to "internal" to generate self-signed certificates for dev environments

Example:

```bash
TLS=internal
```

- Custom - set environment variable TLS to "cert.pem key.pem" where cert.pem and key.pem - are paths to your custom certificates (this needs modifying docker-compose with path to your certificates passed as volumes)

Example:

```bash
TLS=cert.pem key.pem
```

## Custom Caddy configuration files

To add additional caddy config snippets into the caddy virtual host configuration add .conf files to config/caddy-includes/

## Keycloak

Keycloak is an Identity and Access Management software bundled with waldur-docker-compose.

To create a keycloak admin account set `KEYCLOAK_ADMIN` env variable in `docker-compose.yaml` and `KEYCLOAK_ADMIN_PASSWORD` in `.env` file.

After this, you can login to the admin interface at [https://localhost/auth/admin](https://localhost/auth/admin) and create Waldur users.

To use Keycloak as an identity provider within Waldur, follow the instruction [here](https://docs.waldur.com/admin-guide/identities/keycloak/).
The discovery url to connect to Keycloak from the waldur-mastermind-api container is:

```bash
http://keycloak:8080/auth/realms/<YOUR REALM>/.well-known/openid-configuration
```

## Integration with SLURM

The integration is described [here](https://docs.waldur.com/admin-guide/providers/remote-slurm/).

### Whitelabeling settings

To set up whitelabeling, you need to define settings in `./config/waldur-mastermind/whitelabeling.yaml`.
You can see the list of all whitelabeling options below.

#### General whitelabeling settings

- site_name
- site_address
- site_email
- site_phone
- short_page_title
- full_page_title
- brand_color
- brand_label_color
- hero_link_label
- hero_link_url
- site_description
- currency_name
- docs_url
- support_portal_url

#### Logos and images of whitelabeling

The path to a logo is constructed like so:
/etc/waldur/icons - is a path in the container (Keep it like it is) + the name of the logo file from config/whitelabeling directory.

All-together /etc/waldur/icons/file_name_from_whitelabeling_directory

- powered_by_logo
- hero_image
- sidebar_logo
- sidebar_logo_mobile
- site_logo
- login_logo
- favicon
