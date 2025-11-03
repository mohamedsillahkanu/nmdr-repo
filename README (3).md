# DHIS2 Deployment on Render.com

This configuration deploys DHIS2 2.40.5 on Render.com with PostgreSQL database.

## Files

- `Dockerfile` - Container configuration for DHIS2
- `dhis.conf` - DHIS2 configuration template
- `startup.sh` - Startup script that parses database URL and initializes DHIS2
- `render.yaml` - Render deployment configuration

## Prerequisites

1. Render.com account
2. GitHub repository with these files
3. Domain configured (or use Render's provided domain)

## Deployment Steps

### Option 1: Using render.yaml (Recommended)

1. Push all files to your GitHub repository
2. Go to Render Dashboard → New → Blueprint
3. Connect your repository
4. Render will automatically detect `render.yaml` and create:
   - PostgreSQL database (dhis2-db)
   - Web service (dhis2-app)

### Option 2: Manual Setup

1. **Create Database:**
   - New → PostgreSQL
   - Name: `dhis2-db`
   - Database: `dhis2`
   - User: `dhis`
   - Plan: Standard (minimum recommended)
   - Region: Oregon

2. **Create Web Service:**
   - New → Web Service
   - Connect your repository
   - Environment: Docker
   - Plan: Standard (minimum)
   - Region: Oregon (same as database)
   
3. **Configure Environment Variables:**
   - `DATABASE_URL` - Link to dhis2-db connection string
   - `SERVER_URL` - Your application URL (e.g., https://icfsl-nmdr.onrender.com)
   - `ENCRYPTION_PASSWORD` - Generate a secure random string

4. **Add Persistent Disk:**
   - Name: `dhis2-files`
   - Mount path: `/opt/dhis2/files`
   - Size: 10GB (adjust as needed)

## Important Configuration Notes

### Resource Requirements

**Minimum Recommended:**
- Web Service: Standard plan ($25/month) - 2GB RAM
- Database: Standard plan ($20/month) - Sufficient for moderate use

**Production Recommended:**
- Web Service: Pro plan ($85/month) - 4GB RAM
- Database: Pro plan ($90/month)

### First Startup

- Initial startup takes 3-5 minutes
- Database schema is automatically created
- Default credentials:
  - Username: `admin`
  - Password: `district`
  - **CHANGE IMMEDIATELY AFTER FIRST LOGIN**

### Database Initialization

The startup script checks if the database is empty and allows DHIS2 to initialize it automatically on first run.

## Post-Deployment Configuration

1. **Access DHIS2:**
   ```
   https://icfsl-nmdr.onrender.com
   ```

2. **Change Admin Password:**
   - Login with admin/district
   - Go to Profile → Edit → Change password

3. **Configure System Settings:**
   - System Settings → General
   - Set server base URL
   - Configure email settings (if needed)

4. **Import Metadata:**
   - Import your organization units
   - Import data elements and indicators
   - Import user roles and users

## Monitoring

### Health Check
- Endpoint: `/api/system/ping`
- Should return 200 OK when system is ready

### Logs
View logs in Render Dashboard:
- Web service logs for application errors
- Database logs for query issues

### Common Issues

**1. Service keeps restarting:**
- Check memory usage (upgrade to larger plan)
- Review logs for Java heap errors
- Verify database connection

**2. Slow performance:**
- Upgrade database plan
- Increase web service memory
- Review analytics generation settings

**3. File upload failures:**
- Verify persistent disk is mounted
- Check disk space usage
- Review file permissions

## Backup Strategy

### Database Backups
Render automatically backs up PostgreSQL databases:
- Daily backups retained for 7 days (Standard plan)
- Configure backup retention in database settings

### File Storage Backups
For `/opt/dhis2/files`:
- Use Render's disk snapshot feature
- Or implement custom backup to external storage (S3, etc.)

## Scaling Considerations

### Horizontal Scaling
DHIS2 doesn't support horizontal scaling out of the box. For high availability:
- Use Render's database read replicas
- Consider Redis for session management
- Implement CDN for static resources

### Vertical Scaling
Upgrade plans as needed:
- Monitor memory usage
- Watch database connection pool
- Track response times

## Security Recommendations

1. **Use HTTPS only** (enforced by Render)
2. **Change default admin password**
3. **Configure firewall rules** if available
4. **Enable audit logging** in DHIS2
5. **Regular security updates**
6. **Strong encryption password**

## Maintenance

### Updates
To update DHIS2 version:
1. Backup database
2. Update version in Dockerfile
3. Test in staging environment
4. Deploy to production
5. Run database migrations

### Monitoring
Set up monitoring for:
- Application uptime
- Database performance
- Disk usage
- Memory consumption

## Support Resources

- [DHIS2 Documentation](https://docs.dhis2.org/)
- [DHIS2 Community](https://community.dhis2.org/)
- [Render Documentation](https://render.com/docs)
- [GitHub Issues](https://github.com/dhis2/dhis2-core/issues)

## Cost Estimation

**Minimum Setup (Development/Testing):**
- Web Service (Starter): $7/month
- Database (Starter): $7/month
- Total: ~$14/month

**Recommended Setup (Production):**
- Web Service (Standard): $25/month
- Database (Standard): $20/month
- Disk (10GB): $0.25/GB/month = $2.50/month
- Total: ~$47.50/month

**High-Performance Setup:**
- Web Service (Pro): $85/month
- Database (Pro): $90/month
- Disk (50GB): $12.50/month
- Total: ~$187.50/month

## Environment Variables Reference

| Variable | Description | Example |
|----------|-------------|---------|
| DATABASE_URL | PostgreSQL connection string | Provided by Render |
| SERVER_URL | Public URL of your DHIS2 instance | https://icfsl-nmdr.onrender.com |
| ENCRYPTION_PASSWORD | Encryption key for sensitive data | Auto-generated or custom |

## Troubleshooting

### View Startup Logs
```bash
# In Render Dashboard
Logs → Shell → Select dhis2-app
```

### Database Connection Test
The startup script includes automatic database connectivity checks.

### Manual Database Access
```bash
# Connect via Render Shell
psql $DATABASE_URL
```

### Clear Cache
If experiencing issues:
1. Restart web service
2. Clear analytics tables in DHIS2
3. Rebuild indexes if needed

## Next Steps

1. ✅ Deploy infrastructure
2. ✅ Access DHIS2 and change admin password
3. ✅ Import organization hierarchy
4. ✅ Configure users and roles
5. ✅ Import metadata packages
6. ✅ Set up data entry forms
7. ✅ Configure analytics and dashboards
8. ✅ Train users
9. ✅ Monitor and maintain

## Contact

For ICF-SL specific support and customizations, contact your technical team.
