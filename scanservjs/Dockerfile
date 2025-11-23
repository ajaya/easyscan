FROM sbs20/scanservjs:latest

# Install SMB/CIFS mount tools, email dependencies, and inotify-tools
RUN apt-get update && \
    apt-get install -y \
        cifs-utils \
        python3 \
        mailutils \
        inotify-tools \
        && rm -rf /var/lib/apt/lists/*

# Preserve original entrypoint if it exists
RUN mkdir -p /app && \
    if [ -f /entrypoint.sh ]; then \
        cp /entrypoint.sh /app/entrypoint-original.sh && \
        chmod +x /app/entrypoint-original.sh; \
    fi

# Copy post-scan scripts and file watcher
COPY post-scan.sh /app/post-scan.sh
COPY smb-handler.sh /app/smb-handler.sh
COPY email-handler.sh /app/email-handler.sh
COPY file-watcher.sh /app/file-watcher.sh
RUN chmod +x /app/post-scan.sh /app/smb-handler.sh /app/email-handler.sh /app/file-watcher.sh

# Create custom entrypoint that starts both scanservjs and file watcher
COPY entrypoint.sh /app/entrypoint-custom.sh
RUN chmod +x /app/entrypoint-custom.sh

# Use custom entrypoint
ENTRYPOINT ["/app/entrypoint-custom.sh"]
CMD []

