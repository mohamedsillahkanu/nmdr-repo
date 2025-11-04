FROM tomcat:9.0-jdk17-temurin

# Set environment variables
ENV CATALINA_OPTS="-Xms512m -Xmx1536m -XX:+UseG1GC -XX:MaxGCPauseMillis=200"
ENV DHIS2_HOME=/opt/dhis2
ENV JAVA_OPTS="-Ddhis2.home=/opt/dhis2"

# Install required packages
RUN apt-get update && \
    apt-get install -y wget postgresql-client gettext-base && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create DHIS2 directories with proper permissions
RUN mkdir -p /opt/dhis2/files && \
    mkdir -p /opt/dhis2/logs && \
    chmod 755 /opt/dhis2 && \
    chmod 755 /opt/dhis2/files

# Download DHIS2 WAR file (version 2.40.5)
RUN wget -O /usr/local/tomcat/webapps/ROOT.war \
    https://releases.dhis2.org/2.40/dhis2-stable-2.40.5.war && \
    chmod 644 /usr/local/tomcat/webapps/ROOT.war

# Copy configuration file
COPY dhis.conf /opt/dhis2/dhis.conf
RUN chmod 600 /opt/dhis2/dhis.conf

# Copy startup script
COPY startup.sh /usr/local/bin/startup.sh
RUN chmod +x /usr/local/bin/startup.sh

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=180s --retries=3 \
    CMD curl -f http://localhost:8080/api/system/ping || exit 1

# Start with custom script
CMD ["/usr/local/bin/startup.sh"]
