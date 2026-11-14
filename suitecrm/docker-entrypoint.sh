#!/bin/bash
#
# Copyright (C) 2026 Genius Dynamics
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copy the SuiteCRM code into the data volume, install SuiteCRM on the first
# start, keep the site URL in sync with the configured host, then start
# Apache. Variables: SUITECRM_DB_HOST, SUITECRM_DB_PORT, SUITECRM_DB_NAME,
# SUITECRM_DB_USER, SUITECRM_DB_PASSWORD, SUITECRM_SITE_URL,
# SUITECRM_ADMIN_USER, SUITECRM_ADMIN_PASSWORD.
#
set -euo pipefail

cd /var/www/html
image_version=$(cat /usr/src/suitecrm/VERSION)

if [ ! -f VERSION ]; then
    echo "Copying SuiteCRM ${image_version} into the data volume..."
    cp -a /usr/src/suitecrm/. /var/www/html/
    chown -R www-data:www-data /var/www/html
elif [ "$(cat VERSION)" != "${image_version}" ]; then
    echo "WARNING: the data volume holds SuiteCRM $(cat VERSION), the image ships ${image_version}." \
        "Upgrade SuiteCRM with its upgrade procedure." >&2
fi

echo "Waiting for the database..."
for _ in $(seq 1 60); do
    if php -r '
        try {
            new PDO(sprintf("mysql:host=%s;port=%s;dbname=%s", getenv("SUITECRM_DB_HOST"), getenv("SUITECRM_DB_PORT"), getenv("SUITECRM_DB_NAME")),
                getenv("SUITECRM_DB_USER"), getenv("SUITECRM_DB_PASSWORD"));
        } catch (Exception $e) { exit(1); }' 2>/dev/null; then
        db_ready=1
        break
    fi
    sleep 2
done
if [ -z "${db_ready:-}" ]; then
    echo "The database is not reachable" >&2
    exit 1
fi

if [ ! -s public/legacy/config.php ]; then
    echo "Installing SuiteCRM ${image_version}..."
    runuser -u www-data -- php bin/console suitecrm:app:install \
        -u "${SUITECRM_ADMIN_USER}" -p "${SUITECRM_ADMIN_PASSWORD}" \
        -U "${SUITECRM_DB_USER}" -P "${SUITECRM_DB_PASSWORD}" \
        -H "${SUITECRM_DB_HOST}" -Z "${SUITECRM_DB_PORT}" -N "${SUITECRM_DB_NAME}" \
        -S "${SUITECRM_SITE_URL}" -d no -W true
fi

# The host can change with configure-module
if [ -n "${SUITECRM_SITE_URL:-}" ]; then
    sed -i "s|'site_url' => '[^']*'|'site_url' => '${SUITECRM_SITE_URL}'|" public/legacy/config.php
fi

exec docker-php-entrypoint "$@"
