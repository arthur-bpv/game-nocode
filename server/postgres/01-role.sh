#!/bin/sh
set -eu

psql -X -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" \
  -v app_password="$NETBOT_DB_PASSWORD" <<'SQL'
CREATE ROLE netbot LOGIN PASSWORD :'app_password';
ALTER DATABASE netbot OWNER TO netbot;
REVOKE CONNECT ON DATABASE netbot FROM PUBLIC;
SQL
