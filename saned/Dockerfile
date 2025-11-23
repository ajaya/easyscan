FROM debian:bookworm-slim

# Install SANE and utilities
RUN apt-get update && \
    apt-get install -y \
        sane \
        sane-utils \
        gettext-base && \
    rm -rf /var/lib/apt/lists/*

# Copy config files
COPY saned.conf /etc/sane.d/saned.conf.template
COPY dll.conf /etc/sane.d/dll.conf

# Expose SANE network port
EXPOSE 6566

# Start script that processes envsubst and launches saned
CMD sh -c ' \
    envsubst < /etc/sane.d/saned.conf.template > /etc/sane.d/saned.conf && \
    DEBUG_LEVEL=${SANE_DEBUG_LEVEL:-1} && \
    echo "Starting SANE daemon with debug level ${DEBUG_LEVEL}..." && \
    echo "Configuration:" && \
    cat /etc/sane.d/saned.conf && \
    echo "Running: saned -l -b 0.0.0.0 -d ${DEBUG_LEVEL}" && \
    exec saned -l -b 0.0.0.0 -d ${DEBUG_LEVEL} \
    '
