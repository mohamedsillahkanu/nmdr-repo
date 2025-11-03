#!/bin/bash
set -e

echo "=== DHIS2 Startup Script ==="
echo "Parsing database connection string..."

# Parse Render's PostgreSQL connection string
# Format: postgresql://user:password@host:port/database
if [ -n "$DATABASE_URL" ]; then
    # Extract components from DATABASE_URL
    DB_USER=$(echo $DATABASE_URL | sed -n 's/.*:\/\/\([^:]*\):.*/\1/p')
    DB_PASS=$(echo $DATABASE_URL | sed -n 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/p')
    DB_HOST=$(echo $DATABASE_URL | sed -n 's/.*@\([^:]*\):.*/\1/p')
    DB_PORT=$(echo $DATABASE_URL | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')
    DB_NAME=$(echo $DATABASE_URL | sed -n 's/.*\/\([^?]*\).*/\1/p')
    
    export DB_HOST
    export DB_PORT
    export DB_NAME
    export DB_USERNAME=${DB_USER}
    export DB_PASSWORD=${DB_PASS}
    
    echo "Database Host: $DB_HOST"
    echo "Database Port: $DB_PORT"
    echo "Database Name: $DB_NAME"
    echo "Database User: $DB_USERNAME"
else
    echo "ERROR: DATABASE_URL not set"
    exit 1
fi

# Substitute environment variables in dhis.conf
echo "Configuring DHIS2..."
envsubst < /opt/dhis2/dhis.conf > /opt/dhis2/dhis.conf.tmp
mv /opt/dhis2/dhis.conf.tmp /opt/dhis2/dhis.conf
chmod 600 /opt/dhis2/dhis.conf

# Wait for database to be ready
echo "Waiting for database to be ready..."
until pg_isready -h $DB_HOST -p $DB_PORT -U $DB_USERNAME; do
    echo "Database is unavailable - sleeping"
    sleep 2
done

echo "Database is ready!"

# Initialize DHIS2 database if needed
echo "Checking database initialization..."
export PGPASSWORD=$DB_PASSWORD
TABLE_COUNT=$(psql -h $DB_HOST -p $DB_PORT -U $DB_USERNAME -d $DB_NAME -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null || echo "0")

if [ "$TABLE_COUNT" -lt "10" ]; then
    echo "Database appears to be empty. DHIS2 will initialize on first start..."
else
    echo "Database already initialized with $TABLE_COUNT tables."
fi

# Start Tomcat
echo "Starting Tomcat..."
exec catalina.sh run
