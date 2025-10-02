# C2 Enumeration Toolkit - Dockerfile
# Multi-stage build for optimized image size and security

FROM debian:bookworm-slim as builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Final runtime image
FROM debian:bookworm-slim

LABEL maintainer="SWORDIntel"
LABEL description="C2 Enumeration Toolkit - Defensive security analysis for .onion C2 infrastructure"
LABEL version="2.1"

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    SOCKS=127.0.0.1:9050 \
    LANG=C.UTF-8

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core requirements
    bash \
    curl \
    coreutils \
    # Tor
    tor \
    torsocks \
    # PCAP tools
    tcpdump \
    tshark \
    # Binary analysis
    binutils \
    file \
    # Compression
    zstd \
    # Utilities
    git \
    jq \
    dialog \
    less \
    procps \
    iproute2 \
    sudo \
    # Python for KP14 integration
    python3 \
    python3-pip \
    python3-venv \
    # Optional but useful
    vim-tiny \
    openssl \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Install Python dependencies for KP14
COPY kp14/requirements.txt /tmp/kp14-requirements.txt
RUN pip3 install --no-cache-dir -r /tmp/kp14-requirements.txt && \
    rm /tmp/kp14-requirements.txt

# Install OpenVINO for hardware acceleration (NPU/GPU/GNA/CPU)
RUN pip3 install --no-cache-dir openvino==2025.3.0

# Create non-root user for security
RUN useradd -m -u 1000 -s /bin/bash c2enum && \
    mkdir -p /home/c2enum/toolkit /home/c2enum/output && \
    chown -R c2enum:c2enum /home/c2enum && \
    # Allow c2enum user to start Tor without password
    echo "c2enum ALL=(debian-tor) NOPASSWD: /usr/bin/tor" >> /etc/sudoers.d/c2enum && \
    chmod 0440 /etc/sudoers.d/c2enum

# Copy toolkit files
COPY --chown=c2enum:c2enum c2-enum-tui.sh /home/c2enum/toolkit/
COPY --chown=c2enum:c2enum c2-scan-comprehensive.sh /home/c2enum/toolkit/
COPY --chown=c2enum:c2enum c2-enum-cli.sh /home/c2enum/toolkit/
COPY --chown=c2enum:c2enum analyzers/ /home/c2enum/toolkit/analyzers/
COPY --chown=c2enum:c2enum kp14/ /home/c2enum/toolkit/kp14/
COPY --chown=c2enum:c2enum *.md /home/c2enum/toolkit/

# Make scripts executable
RUN chmod +x /home/c2enum/toolkit/c2-enum-tui.sh && \
    chmod +x /home/c2enum/toolkit/c2-scan-comprehensive.sh && \
    chmod +x /home/c2enum/toolkit/c2-enum-cli.sh && \
    chmod +x /home/c2enum/toolkit/analyzers/*.sh

# Grant tcpdump capabilities for PCAP (non-root capture)
RUN setcap cap_net_raw,cap_net_admin=eip /usr/bin/tcpdump && \
    setcap cap_net_raw,cap_net_admin=eip /usr/bin/dumpcap

# Configure Tor
RUN mkdir -p /var/lib/tor && \
    chown -R debian-tor:debian-tor /var/lib/tor && \
    chmod 700 /var/lib/tor

COPY --chown=debian-tor:debian-tor docker/torrc /etc/tor/torrc

# Health check for Tor
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl --socks5-hostname 127.0.0.1:9050 -s https://check.torproject.org/api/ip | grep -q '"IsTor":true' || exit 1

# Switch to non-root user
USER c2enum
WORKDIR /home/c2enum

# Set up volume for outputs
VOLUME ["/home/c2enum/output"]

# Expose nothing (all traffic via Tor SOCKS)

# Entry point script
COPY --chown=c2enum:c2enum docker/entrypoint.sh /home/c2enum/
RUN chmod +x /home/c2enum/entrypoint.sh

ENTRYPOINT ["/home/c2enum/entrypoint.sh"]
CMD ["/home/c2enum/toolkit/c2-enum-tui.sh"]
