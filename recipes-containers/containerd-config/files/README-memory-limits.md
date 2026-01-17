# Container Memory Limits Configuration

## Overview

This system enforces a **global memory limit of 7.4GB for ALL containers combined** to prevent device lockup:

- **Total Memory**: ~7.6GB
- **System Reserved**: ~200MB for OS (kernel, systemd, essential services)
- **Containerd + All Containers**: 7.4GB maximum
- **Swap File**: 4GB (`/data/swapfile`) for temporary spikes

## How It Works

The containerd service is configured with systemd cgroup limits:

- **MemoryMax=7.4G**: Hard limit - containerd killed if exceeded
- **MemoryHigh=6.5G**: Soft limit - throttling begins at this threshold
- **Swap Available**: 4GB additional buffer for memory pressure

This means **all running containers share the 7.4GB pool**. Individual containers are NOT limited separately.

## Configuration

The limit is enforced via systemd drop-in:
- **File**: `/etc/systemd/system/containerd.service.d/memory-limit.conf`
- **Applied to**: containerd daemon and all child containers

## Monitoring Memory Usage

### Check Total Container Memory
```bash
# View all containers memory usage
nerdctl stats

# Check containerd cgroup memory
systemctl status containerd
cat /sys/fs/cgroup/system.slice/containerd.service/memory.current
cat /sys/fs/cgroup/system.slice/containerd.service/memory.max
```

### Check System Memory
```bash
# Overall system memory
free -h

# Swap usage
swapon --show

# Memory pressure
cat /sys/fs/cgroup/system.slice/containerd.service/memory.pressure
```

## What Happens When Limit is Reached

1. **At 6.5GB (MemoryHigh)**: Containerd and containers are throttled
2. **At 7.4GB (MemoryMax)**:
   - If swap available: System uses swap (up to 4GB)
   - If swap full: containerd service is killed by OOM killer
   - Containers are stopped gracefully

## Managing Container Memory

Since all containers share 7.4GB:

### Running Fewer Containers
Better to run 2-3 memory-intensive containers than many small ones:
```bash
# Good: 2 containers using 3GB each = 6GB total
nerdctl run -d --name ml-model1 myimage
nerdctl run -d --name ml-model2 myimage

# Bad: 10 containers using 800MB each = 8GB total (exceeds limit!)
```

### Monitoring Before Launch
Check available memory before starting new containers:
```bash
# Check current usage
USED=$(nerdctl stats --no-stream --format "{{.MemUsage}}" | awk '{sum+=$1} END {print sum}')
echo "Currently using: ${USED}GB of 7.4GB"
```

### Setting Individual Container Limits (Optional)
While not enforced, you can still use memory flags for documentation:
```bash
# Request 2GB for this container (advisory only)
nerdctl run --memory="2g" myimage
```

## Troubleshooting

### Containerd Service Killed
If you see containerd restart unexpectedly:
```bash
# Check if OOM killed it
journalctl -xeu containerd | grep -i "killed\|oom"

# View memory usage history
systemd-cgtop
```

**Solution**: Stop some containers to free memory

### Containers Running Slow
If containers are throttled (>6.5GB total):
```bash
# Check memory pressure
cat /sys/fs/cgroup/system.slice/containerd.service/memory.pressure
```

**Solution**:
- Stop non-critical containers
- Wait for swap to help during temporary spikes

### Out of Memory (OOM) Events
```bash
# Check kernel OOM logs
dmesg | grep -i "out of memory\|oom"

# Check swap usage
free -h
```

**Solution**: Reduce total container memory footprint

## Best Practices

1. **Monitor Total Usage**: Keep combined container memory under 6GB for headroom
2. **Use Swap Wisely**: 4GB swap is for temporary spikes, not steady state
3. **Stop Unused Containers**: Free memory immediately
4. **Plan Container Mix**: Know each container's memory needs before launching
5. **Test Under Load**: Ensure your container mix fits within 7.4GB limit

## Configuration Files

- Systemd drop-in: `/etc/systemd/system/containerd.service.d/memory-limit.conf`
- Swap file: `/data/swapfile` (4GB)
- This README: `/usr/share/doc/containerd-config/README-memory-limits.md`

## Adjusting the Limit

To change the global limit, edit the systemd drop-in and reload:
```bash
# Edit the limit
vi /etc/systemd/system/containerd.service.d/memory-limit.conf

# Reload systemd
systemctl daemon-reload

# Restart containerd
systemctl restart containerd
```
