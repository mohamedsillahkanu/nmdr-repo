#!/bin/bash
# DHIS2 Database Management Script
# Run this script in Render Shell for database operations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Parse DATABASE_URL
parse_db_url() {
    export DB_USER=$(echo $DATABASE_URL | sed -n 's/.*:\/\/\([^:]*\):.*/\1/p')
    export DB_PASS=$(echo $DATABASE_URL | sed -n 's/.*:\/\/[^:]*:\([^@]*\)@.*/\1/p')
    export DB_HOST=$(echo $DATABASE_URL | sed -n 's/.*@\([^:]*\):.*/\1/p')
    export DB_PORT=$(echo $DATABASE_URL | sed -n 's/.*:\([0-9]*\)\/.*/\1/p')
    export DB_NAME=$(echo $DATABASE_URL | sed -n 's/.*\/\([^?]*\).*/\1/p')
    export PGPASSWORD=$DB_PASS
}

# Database info
db_info() {
    echo -e "${GREEN}=== Database Information ===${NC}"
    echo "Host: $DB_HOST"
    echo "Port: $DB_PORT"
    echo "Database: $DB_NAME"
    echo "User: $DB_USER"
    echo ""
}

# Check database size
db_size() {
    echo -e "${GREEN}=== Database Size ===${NC}"
    psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "
        SELECT 
            pg_size_pretty(pg_database_size('$DB_NAME')) as database_size,
            pg_size_pretty(pg_total_relation_size('dataelement')) as dataelement_size,
            pg_size_pretty(pg_total_relation_size('datavalue')) as datavalue_size,
            pg_size_pretty(pg_total_relation_size('organisationunit')) as orgunit_size;
    "
    echo ""
}

# Table counts
table_counts() {
    echo -e "${GREEN}=== Important Table Counts ===${NC}"
    psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "
        SELECT 'Data Values' as table_name, COUNT(*) as row_count FROM datavalue
        UNION ALL
        SELECT 'Data Elements', COUNT(*) FROM dataelement
        UNION ALL
        SELECT 'Organisation Units', COUNT(*) FROM organisationunit
        UNION ALL
        SELECT 'Users', COUNT(*) FROM userinfo
        UNION ALL
        SELECT 'Analytics Tables', COUNT(*) FROM analytics
        ORDER BY table_name;
    "
    echo ""
}

# Connection stats
connection_stats() {
    echo -e "${GREEN}=== Database Connections ===${NC}"
    psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "
        SELECT 
            count(*) as total_connections,
            count(*) FILTER (WHERE state = 'active') as active_connections,
            count(*) FILTER (WHERE state = 'idle') as idle_connections
        FROM pg_stat_activity 
        WHERE datname = '$DB_NAME';
    "
    echo ""
}

# Vacuum analyze
vacuum_analyze() {
    echo -e "${YELLOW}=== Running VACUUM ANALYZE ===${NC}"
    echo "This may take several minutes..."
    psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "VACUUM ANALYZE;"
    echo -e "${GREEN}VACUUM ANALYZE completed${NC}"
    echo ""
}

# Reset admin password
reset_admin_password() {
    echo -e "${YELLOW}=== Reset Admin Password ===${NC}"
    read -sp "Enter new password for admin: " NEW_PASS
    echo ""
    
    # BCrypt hash (this is simplified - DHIS2 uses BCrypt)
    # For actual password reset, use DHIS2 UI or API
    echo -e "${RED}Warning: This requires DHIS2 to be running${NC}"
    echo "Use DHIS2 UI: Profile > Edit User > Change Password"
    echo "Or use API:"
    echo "curl -X PUT 'https://icfsl-nmdr.onrender.com/api/users/{userId}/password' \\"
    echo "  -u admin:oldpassword \\"
    echo "  -H 'Content-Type: text/plain' \\"
    echo "  -d 'newpassword'"
    echo ""
}

# Backup database
backup_db() {
    echo -e "${YELLOW}=== Creating Database Backup ===${NC}"
    BACKUP_FILE="dhis2_backup_$(date +%Y%m%d_%H%M%S).sql"
    echo "Backing up to: $BACKUP_FILE"
    pg_dump -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -F c -f $BACKUP_FILE
    echo -e "${GREEN}Backup created: $BACKUP_FILE${NC}"
    echo "File size: $(du -h $BACKUP_FILE | cut -f1)"
    echo ""
}

# Show analytics tables
analytics_info() {
    echo -e "${GREEN}=== Analytics Tables ===${NC}"
    psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "
        SELECT 
            schemaname,
            tablename,
            pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
        FROM pg_tables 
        WHERE tablename LIKE 'analytics_%' 
        ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC 
        LIMIT 10;
    "
    echo ""
}

# Check slow queries
slow_queries() {
    echo -e "${GREEN}=== Slow Queries (>1 second) ===${NC}"
    psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "
        SELECT 
            pid,
            now() - query_start as duration,
            state,
            LEFT(query, 100) as query
        FROM pg_stat_activity
        WHERE state != 'idle' 
            AND now() - query_start > interval '1 second'
            AND datname = '$DB_NAME'
        ORDER BY duration DESC;
    "
    echo ""
}

# Main menu
show_menu() {
    echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   DHIS2 Database Management Tool      ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
    echo ""
    echo "1) Database Information"
    echo "2) Database Size"
    echo "3) Table Counts"
    echo "4) Connection Statistics"
    echo "5) Analytics Tables Info"
    echo "6) Slow Queries"
    echo "7) Run VACUUM ANALYZE"
    echo "8) Backup Database"
    echo "9) Reset Admin Password Guide"
    echo "0) Exit"
    echo ""
}

# Main execution
main() {
    if [ -z "$DATABASE_URL" ]; then
        echo -e "${RED}ERROR: DATABASE_URL not set${NC}"
        exit 1
    fi
    
    parse_db_url
    
    while true; do
        show_menu
        read -p "Enter choice [0-9]: " choice
        echo ""
        
        case $choice in
            1) db_info ;;
            2) db_size ;;
            3) table_counts ;;
            4) connection_stats ;;
            5) analytics_info ;;
            6) slow_queries ;;
            7) vacuum_analyze ;;
            8) backup_db ;;
            9) reset_admin_password ;;
            0) 
                echo -e "${GREEN}Goodbye!${NC}"
                exit 0 
                ;;
            *) 
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
        
        read -p "Press Enter to continue..."
        clear
    done
}

# Run main if script is executed
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main
fi
