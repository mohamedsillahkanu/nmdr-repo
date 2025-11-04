#!/bin/bash
set -e

echo "=== DHIS2 Startup Script ==="
echo "Parsing database connection string..."

# Parse Render's PostgreSQL connection string
if [ -z "$DATABASE_URL" ]; then
    echo "ERROR: DATABASE_URL not set"
    exit 1
fi

# Show URL format (hide password)
SAFE_URL=$(echo "$DATABASE_URL" | sed 's/:\/\/[^:]*:[^@]*@/:\/\/user:****@/')
echo "Connection string format: $SAFE_URL"

# Use Python for reliable URL parsing
if command -v python3 &> /dev/null; then
    echo "Using Python for URL parsing..."
    read DB_HOST DB_PORT DB_NAME DB_USERNAME DB_PASSWORD <<< $(python3 -c "
import urllib.parse
url = urllib.parse.urlparse('$DATABASE_URL')
print(url.hostname or '', url.port or '5432', url.path[1:] or '', url.username or '', url.password or '')
")
else
    echo "Using shell parsing..."
    DB_URL_NO_PROTO="${DATABASE_URL#*://}"
    DB_CREDS="${DB_URL_NO_PROTO%%@*}"
    DB_USERNAME="${DB_CREDS%%:*}"
    DB_PASSWORD="${DB_CREDS#*:}"
    DB_LOCATION="${DB_URL_NO_PROTO#*@}"
    DB_HOST="${DB_LOCATION%%:*}"
    DB_PORT_AND_DB="${DB_LOCATION#*:}"
    DB_PORT="${DB_PORT_AND_DB%%/*}"
    DB_NAME="${DB_PORT_AND_DB#*/}"
    DB_NAME="${DB_NAME%%\?*}"
fi

# Export variables
export DB_HOST
export DB_PORT
export DB_NAME
export DB_USERNAME
export DB_PASSWORD

echo "Database Host: $DB_HOST"
echo "Database Port: $DB_PORT"
echo "Database Name: $DB_NAME"
echo "Database User: $DB_USERNAME"

# Validate
if [ -z "$DB_HOST" ] || [ -z "$DB_PORT" ] || [ -z "$DB_NAME" ] || [ -z "$DB_USERNAME" ]; then
    echo "ERROR: Failed to parse database connection details"
    exit 1
fi

# Substitute environment variables in dhis.conf
echo "Configuring DHIS2..."
envsubst < /opt/dhis2/dhis.conf > /opt/dhis2/dhis.conf.tmp
mv /opt/dhis2/dhis.conf.tmp /opt/dhis2/dhis.conf
chmod 600 /opt/dhis2/dhis.conf

# Wait for database
echo "Waiting for database to be ready..."
export PGPASSWORD=$DB_PASSWORD

MAX_RETRIES=60
RETRY_COUNT=0

while ! pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USERNAME" > /dev/null 2>&1; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "ERROR: Database did not become ready after $MAX_RETRIES attempts"
        exit 1
    fi
    echo "Attempt $RETRY_COUNT/$MAX_RETRIES: Database is unavailable - sleeping 2 seconds..."
    sleep 2
done

echo "✓ Database is ready!"

# Check database initialization
echo "Checking database initialization..."
TABLE_COUNT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USERNAME" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | tr -d ' ' || echo "0")

echo "Found $TABLE_COUNT tables in database"

if [ "$TABLE_COUNT" -lt "10" ]; then
    echo "Database appears empty. DHIS2 will initialize on first start (5-10 minutes)..."
else
    echo "Database already initialized with $TABLE_COUNT tables."
fi

# Start Tomcat
echo "Starting Tomcat..."
echo "This may take 3-5 minutes for DHIS2 to fully start..."
exec catalina.sh run
