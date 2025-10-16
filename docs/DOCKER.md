# Docker Deployment Guide

## Why Docker for C2 Enumeration Toolkit?

### 🎯 Key Benefits

#### 1. **Isolation & Security**
- ✅ Sandboxed environment prevents contamination
- ✅ No system-wide Tor installation required
- ✅ Network isolation from host system
- ✅ Containerized outputs (can't escape container)
- ✅ Non-root user execution (UID 1000)
- ✅ Dropped capabilities (minimal privileges)

#### 2. **Portability & Reproducibility**
- ✅ Works identically on any Linux/macOS/Windows (Docker Desktop)
- ✅ All dependencies bundled (no "works on my machine")
- ✅ Version-locked tools and libraries
- ✅ Easy distribution to team members
- ✅ CI/CD integration ready

#### 3. **Tor Management**
- ✅ Tor automatically starts with container
- ✅ Pre-configured torrc for optimal C2 analysis
- ✅ Built-in health checks verify Tor connectivity
- ✅ Fresh Tor circuits on each container start
- ✅ No conflicts with host Tor installation

#### 4. **PCAP Capture**
- ✅ tcpdump/tshark capabilities granted safely
- ✅ No sudo required for packet capture
- ✅ PCAP files contained in volume
- ✅ Isolated from host network traffic

#### 5. **Resource Management**
- ✅ CPU and memory limits prevent runaway processes
- ✅ Automatic cleanup on stop
- ✅ Multiple containers for parallel analysis
- ✅ Easy scaling with docker-compose

#### 6. **Operational Benefits**
- ✅ One-command deployment: `docker-compose up`
- ✅ Clean shutdown: `docker-compose down`
- ✅ Easy updates: rebuild image
- ✅ Persistent outputs via volumes
- ✅ Log aggregation ready

---

## 🚀 Quick Start

### Prerequisites
```bash
# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# Install Docker Compose (if not included)
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" \
  -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### Build & Run

#### Option 1: Docker Compose (Recommended)
```bash
# Build and start
docker-compose up -d

# View logs
docker-compose logs -f

# Attach to interactive session
docker attach c2-enum-toolkit

# Stop
docker-compose down
```

#### Option 2: Docker CLI
```bash
# Build image
docker build -t c2-enum-toolkit:2.1 .

# Run interactively
docker run -it --rm \
  --name c2enum \
  --cap-add NET_RAW \
  --cap-add NET_ADMIN \
  -v $(pwd)/output:/home/c2enum/output \
  c2-enum-toolkit:2.1

# Run with custom arguments
docker run -it --rm \
  --name c2enum \
  --cap-add NET_RAW \
  -v $(pwd)/output:/home/c2enum/output \
  c2-enum-toolkit:2.1 \
  /home/c2enum/toolkit/c2-enum-tui.sh --no-pcap --quiet
```

---

## 📁 Directory Structure

```
c2-enum-toolkit/
├── Dockerfile              # Main container definition
├── docker-compose.yml      # Orchestration config
├── .dockerignore          # Build exclusions
├── docker/
│   ├── torrc              # Tor configuration
│   └── entrypoint.sh      # Startup script
├── output/                # Mounted volume for results
└── c2-enum-tui.sh        # Main script
```

---

## 🔧 Configuration

### Environment Variables

Set in `docker-compose.yml` or via `-e` flag:

```yaml
environment:
  - SOCKS=127.0.0.1:9050       # Tor SOCKS proxy
  - TZ=UTC                      # Timezone
  - VERBOSE=true                # Verbose output
```

### Volume Mounts

**Output Directory:**
```yaml
volumes:
  - ./output:/home/c2enum/output:rw
```
All enumeration results saved here, accessible on host.

**Custom Targets:**
```yaml
volumes:
  - ./my-targets.txt:/home/c2enum/targets.txt:ro
```
Mount custom target file (read-only).

**Config Persistence:**
```yaml
volumes:
  - ./config:/home/c2enum/.config:rw
```
Save preferences between runs.

### Resource Limits

Adjust in `docker-compose.yml`:

```yaml
deploy:
  resources:
    limits:
      cpus: '2.0'      # Max 2 CPU cores
      memory: 2G       # Max 2GB RAM
    reservations:
      cpus: '0.5'      # Guaranteed 0.5 cores
      memory: 512M     # Guaranteed 512MB
```

---

## 🛠️ Advanced Usage

### Custom Tor Configuration

Edit `docker/torrc` before building:

```
# Increase circuit timeout
CircuitBuildTimeout 120

# Use specific exit countries
ExitNodes {US},{GB},{DE}
StrictNodes 1
```

Rebuild: `docker-compose build`

### Multiple Parallel Containers

```bash
# Run 3 instances analyzing different targets
docker-compose up --scale c2-enum=3
```

### Debugging Container

```bash
# Shell into running container
docker exec -it c2-enum-toolkit bash

# Check Tor status
docker exec c2-enum-toolkit curl --socks5-hostname 127.0.0.1:9050 \
  https://check.torproject.org/api/ip

# View Tor logs
docker exec c2-enum-toolkit cat /var/log/tor/notices.log
```

### Health Checks

```bash
# View health status
docker inspect c2-enum-toolkit | jq '.[0].State.Health'

# Manual health check
docker exec c2-enum-toolkit curl --socks5-hostname 127.0.0.1:9050 -s \
  https://check.torproject.org/api/ip | jq .
```

---

## 📊 Operational Workflows

### Workflow 1: Quick Analysis
```bash
# Start container
docker-compose up -d

# Wait for Tor to be ready (check logs)
docker-compose logs -f c2-enum

# Attach to TUI
docker attach c2-enum-toolkit

# Press R for reachability check
# Press 1 to enumerate
# Press E to export JSON

# Detach: Ctrl+P, Ctrl+Q
# Stop: docker-compose down

# Results in ./output/
```

### Workflow 2: Batch Processing
```bash
# Create custom targets file
cat > targets.txt <<EOF
evil1.onion
evil2.onion:9000
evil3.onion
EOF

# Run in batch mode (non-interactive)
docker run --rm \
  --cap-add NET_RAW \
  -v $(pwd)/output:/home/c2enum/output \
  -v $(pwd)/targets.txt:/tmp/targets.txt:ro \
  c2-enum-toolkit:2.1 \
  /home/c2enum/toolkit/c2-enum-tui.sh \
    --targets $(cat targets.txt | tr '\n' ',') \
    --quiet \
    --no-pcap
```

### Workflow 3: Continuous Monitoring
```bash
# Create monitoring script
cat > docker/monitor.sh <<'EOF'
#!/bin/bash
while true; do
  /home/c2enum/toolkit/c2-enum-tui.sh \
    --no-auto-enum --quiet \
    -o /home/c2enum/output/scan_$(date +%Y%m%d_%H%M%S)
  sleep 3600  # Run every hour
done
EOF

# Build with monitoring
docker build -t c2-enum-toolkit:monitor .

# Run as daemon
docker run -d \
  --name c2enum-monitor \
  --cap-add NET_RAW \
  -v $(pwd)/output:/home/c2enum/output \
  c2-enum-toolkit:monitor \
  /bin/bash /home/c2enum/docker/monitor.sh
```

---

## 🔒 Security Considerations

### Container Security Features

1. **Non-root User**
   - Runs as UID 1000 (`c2enum`)
   - Cannot escalate privileges

2. **Dropped Capabilities**
   ```yaml
   cap_drop:
     - ALL
   cap_add:
     - NET_RAW    # Only for PCAP
     - NET_ADMIN  # Only for network ops
   ```

3. **No New Privileges**
   ```yaml
   security_opt:
     - no-new-privileges:true
   ```

4. **Network Isolation**
   - No exposed ports
   - All traffic via Tor SOCKS
   - Bridge network (not host)

5. **Read-only Filesystem (Optional)**
   ```yaml
   read_only: true
   tmpfs:
     - /tmp
     - /var/lib/tor
   ```

### Host Isolation

**What the container CAN'T do:**
- ❌ Access host filesystem (except mounted volumes)
- ❌ See host processes
- ❌ Modify host network settings
- ❌ Access other containers (unless networked)
- ❌ Execute binaries on host

**What the container CAN do:**
- ✅ Make HTTP requests via Tor
- ✅ Capture packets on container interfaces
- ✅ Write to mounted output volume
- ✅ Read mounted config files

---

## 🐛 Troubleshooting

### Tor Won't Start

**Symptom:** Container exits immediately

**Solution:**
```bash
# Check logs
docker-compose logs c2-enum

# Common issues:
# 1. Port 9050 already in use
sudo ss -ltnp | grep 9050
sudo systemctl stop tor  # Stop host Tor

# 2. Permission issues
docker-compose down
docker-compose up --build
```

### PCAP Capture Fails

**Symptom:** "Permission denied" for tcpdump

**Solution:**
```bash
# Ensure capabilities are granted
docker run --rm --cap-add NET_RAW --cap-add NET_ADMIN ...

# Or in docker-compose.yml:
cap_add:
  - NET_RAW
  - NET_ADMIN
```

### Output Directory Empty

**Symptom:** No files in ./output/

**Solution:**
```bash
# Check volume mount
docker inspect c2-enum-toolkit | jq '.[0].Mounts'

# Verify permissions
ls -la output/
sudo chown -R $(id -u):$(id -g) output/

# Run with explicit output path
docker exec c2-enum-toolkit ls -la /home/c2enum/output
```

### Container Exits Immediately

**Symptom:** Container starts then stops

**Solutions:**
```bash
# 1. Check logs
docker logs c2-enum-toolkit

# 2. Run shell instead
docker run -it --rm c2-enum-toolkit:2.1 /bin/bash

# 3. Disable health check temporarily
docker run --no-healthcheck ...

# 4. Check entrypoint
docker run --entrypoint /bin/bash -it c2-enum-toolkit:2.1
```

---

## 📦 Image Management

### Build Optimizations

**Multi-stage build** (already implemented):
```dockerfile
FROM debian:bookworm-slim as builder
# ... build dependencies

FROM debian:bookworm-slim
# ... runtime only
```

**Layer caching:**
```bash
# Order Dockerfile commands from least to most frequently changed
# Dependencies (rarely change) first
# Source code (changes often) last
```

### Image Size

```bash
# Check image size
docker images c2-enum-toolkit

# Reduce size:
# 1. Use slim base image ✓
# 2. Combine RUN commands ✓
# 3. Clean apt cache ✓
# 4. Multi-stage build ✓

# Expected size: ~300-400MB
```

### Updating

```bash
# Pull latest base image
docker pull debian:bookworm-slim

# Rebuild
docker-compose build --no-cache

# Or rebuild single layer
docker-compose build --pull
```

---

## 🌐 Network Modes

### Bridge (Default)
```yaml
network_mode: bridge
```
- Isolated network
- Container-to-container communication
- NAT to host

### Host (Not Recommended)
```yaml
network_mode: host
```
- Direct access to host network
- No isolation
- Use for debugging only

### None (Maximum Isolation)
```yaml
network_mode: none
```
- No network access
- For offline analysis only

---

## 📈 Monitoring & Logging

### Container Logs

```bash
# Follow logs
docker-compose logs -f

# Last 100 lines
docker-compose logs --tail=100

# Specific service
docker-compose logs c2-enum

# Save to file
docker-compose logs > container.log
```

### Application Logs

```bash
# View toolkit log
docker exec c2-enum-toolkit cat /home/c2enum/output/c2-enum.log

# Tail toolkit log
docker exec c2-enum-toolkit tail -f /home/c2enum/output/c2-enum.log
```

### Resource Usage

```bash
# Real-time stats
docker stats c2-enum-toolkit

# One-time snapshot
docker stats --no-stream c2-enum-toolkit
```

---

## 🔄 CI/CD Integration

### GitHub Actions Example

```yaml
name: Build Docker Image

on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Build image
        run: docker build -t c2-enum-toolkit:latest .

      - name: Test image
        run: |
          docker run --rm c2-enum-toolkit:latest \
            /home/c2enum/toolkit/c2-enum-tui.sh --help

      - name: Push to registry
        run: |
          echo ${{ secrets.GITHUB_TOKEN }} | docker login ghcr.io -u ${{ github.actor }} --password-stdin
          docker tag c2-enum-toolkit:latest ghcr.io/${{ github.repository }}:latest
          docker push ghcr.io/${{ github.repository }}:latest
```

---

## 🎯 Best Practices

### 1. **Always Use Volumes**
Don't rely on container filesystem - it's ephemeral.

### 2. **Version Your Images**
```bash
docker build -t c2-enum-toolkit:2.1 .
docker build -t c2-enum-toolkit:latest .
```

### 3. **Limit Resources**
Prevent runaway containers from consuming all system resources.

### 4. **Use Health Checks**
Ensure Tor is working before analysis begins.

### 5. **Clean Up**
```bash
# Remove stopped containers
docker container prune

# Remove unused images
docker image prune

# Remove unused volumes
docker volume prune
```

### 6. **Backup Outputs**
```bash
# Automated backup
tar -czf output-backup-$(date +%F).tar.gz output/
```

---

## 🔮 Future Enhancements

### Planned Docker Features

- [ ] Multi-architecture builds (ARM64, x86_64)
- [ ] Kubernetes deployment manifests
- [ ] Pre-built images on Docker Hub / GHCR
- [ ] Rootless Docker support
- [ ] SELinux policies
- [ ] AppArmor profiles
- [ ] Distributed analysis with Docker Swarm

---

## 📚 Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [Tor in Docker](https://hub.docker.com/r/dperson/torproxy)

---

## ✅ Summary

**Benefits Recap:**
1. ✅ Complete isolation from host system
2. ✅ Reproducible environment across platforms
3. ✅ Automatic Tor management
4. ✅ Safe PCAP capture without sudo
5. ✅ Easy deployment and scaling
6. ✅ Resource management
7. ✅ Persistent outputs via volumes
8. ✅ Security hardening built-in
9. ✅ CI/CD ready
10. ✅ Team distribution simplified

**Recommended Usage:**
- Use Docker for production deployments
- Use native script for development/testing
- Use docker-compose for orchestration
- Mount volumes for persistent data
- Monitor resource usage
- Regular image updates

---

**🚀 Docker makes C2 Enumeration Toolkit portable, secure, and production-ready!**
