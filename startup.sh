#!/bin/bash
set -e

echo "=== DHIS2 Startup Script ==="
echo "Parsing database connection string..."

# Parse Render's PostgreSQL connection string
# Format: postgresql://user:password@host:port/database
if [ -z "$DATABASE_URL" ]; then
    echo "ERROR: DATABASE_URL not set"
    exit 1
fi

# Show URL format (hide password for security)
SAFE_URL=$(echo "$DATABASE_URL" | sed 's/:\/\/[^:]*:[^@]*@/:\/\/user:****@/')
echo "Connection string format: $SAFE_URL"

# Method 1: Try using Python (more reliable)
if command -v python3 &> /dev/null; then
    echo "Using Python for URL parsing..."
    read DB_HOST DB_PORT DB_NAME DB_USERNAME DB_PASSWORD <<< $(python3 -c "
import urllib.parse
url = urllib.parse.urlparse('$DATABASE_URL')
print(url.hostname or '', url.port or '5432', url.path[1:] or '', url.username or '', url.password or '')
")
# Method 2: Fallback to manual parsing
else
    echo "Using shell parsing..."
    # Remove protocol
    DB_URL_NO_PROTO="${DATABASE_URL#*://}"
    
    # Extract credentials (everything before @)
    DB_CREDS="${DB_URL_NO_PROTO%%@*}"
    DB_USERNAME="${DB_CREDS%%:*}"
    DB_PASSWORD="${DB_CREDS#*:}"
    
    # Extract host:port/database (everything after @)
    DB_LOCATION="${DB_URL_NO_PROTO#*@}"
    
    # Extract host (everything before :)
    DB_HOST="${DB_LOCATION%%:*}"
    
    # Extract port and database
    DB_PORT_AND_DB="${DB_LOCATION#*:}"
    DB_PORT="${DB_PORT_AND_DB%%/*}"
    DB_NAME="${DB_PORT_AND_DB#*/}"
    
    # Clean database name (remove query params if any)
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

# Validate all required variables are set
if [ -z "$DB_HOST" ] || [ -z "$DB_PORT" ] || [ -z "$DB_NAME" ] || [ -z "$DB_USERNAME" ]; then
    echo "ERROR: Failed to parse database connection details"
    echo "DB_HOST='$DB_HOST'"
    echo "DB_PORT='$DB_PORT'"
    echo "DB_NAME='$DB_NAME'"
    echo "DB_USERNAME='$DB_USERNAME'"
    exit 1
fi

# Substitute environment variables in dhis.conf
echo "Configuring DHIS2..."
envsubst < /opt/dhis2/dhis.conf > /opt/dhis2/dhis.conf.tmp
mv /opt/dhis2/dhis.conf.tmp /opt/dhis2/dhis.conf
chmod 600 /opt/dhis2/dhis.conf

# Wait for database to be ready
echo "Waiting for database to be ready..."
export PGPASSWORD=$DB_PASSWORD

MAX_RETRIES=60
RETRY_COUNT=0

while ! pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USERNAME" > /dev/null 2>&1; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "ERROR: Database did not become ready after $MAX_RETRIES attempts"
        echo "Please check:"
        echo "1. Database service is running"
        echo "2. Database is in the same region as web service"
        echo "3. DATABASE_URL environment variable is correct"
        exit 1
    fi
    echo "Attempt $RETRY_COUNT/$MAX_RETRIES: Database is unavailable - sleeping 2 seconds..."
    sleep 2
done

echo "✓ Database is ready!"

# Check if database is initialized
echo "Checking database initialization..."
TABLE_COUNT=$(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USERNAME" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | tr -d ' ' || echo "0")

echo "Found $TABLE_COUNT tables in database"

if [ "$TABLE_COUNT" -lt "10" ]; then
    echo "Database appears empty. DHIS2 will initialize on first start (this may take 5-10 minutes)..."
else
    echo "Database already initialized with $TABLE_COUNT tables."
fi

# Start Tomcat
echo "Starting Tomcat..."
echo "This may take 3-5 minutes for DHIS2 to fully start..."
exec catalina.sh run
