# VM Requirements & Specifications

Detailed hardware requirements for running a Dogecoin node.

## Quick Reference

| Resource | Minimum | Recommended (Mining Pool) |
|----------|---------|---------------------------|
| RAM | 4GB | 8GB |
| Disk | 400GB SSD | 500GB NVMe/SSD |
| CPU | 2 cores | 4 cores |
| Network | 100Mbps | 1Gbps |
| OS | Debian 13 (Trixie) | |

> **⚠️ Current blockchain size (Dec 2024):** ~265 GB. With txindex for mining: ~330-360 GB total.

## Storage Requirements

| Component | Size (Dec 2024) |
|-----------|-----------------|
| Full Blockchain | ~265 GB |
| Pruned Blockchain | ~4 GB |
| Transaction Index (txindex) | ~50-80 GB |
| Build Dependencies | ~3 GB |
| Source + Compilation | ~5 GB |
| Logs + Overhead | ~10 GB |
| **Total (Full Node + txindex)** | **~330-360 GB** |
| **Recommended (with growth)** | **400-500 GB** |

> **⚠️ IMPORTANT:** Real-world sync data shows ~265 GB for full blockchain (Dec 2024). Third-party blockchain explorers often report incorrect/compressed sizes. Always provision more than you think you need!

### Comparison with Litecoin

| Coin | Blockchain Size | With txindex | Recommended |
|------|-----------------|--------------|-------------|
| Dogecoin | ~265 GB | ~330-360 GB | **400-500 GB** |
| Litecoin | ~225 GB | ~300-350 GB | 400-500 GB |

> Both coins require similar storage (~400-500 GB) for full node with txindex.

## Why SSD is Required for Mining Pools

Mining pool nodes have specific I/O requirements:

- **Fast Block Verification** - Pool must verify new blocks instantly
- **RPC Response Time** - Miners expect <100ms response from getblocktemplate
- **Transaction Index** - Random reads across entire blockchain (txindex=1)
- **Database Cache** - Frequent reads/writes to chainstate

| Storage Type | Performance | Suitable for Pool? |
|--------------|-------------|-------------------|
| HDD | ~100 IOPS | No |
| SSD | ~10,000+ IOPS | Yes |
| NVMe | ~100,000+ IOPS | Ideal |

## Initial Sync Time Estimates

| Connection | Full Node | Pruned Node |
|------------|-----------|-------------|
| 100 Mbps | 12-24 hours | 2-4 hours |
| 1 Gbps | 4-8 hours | 1-2 hours |

## Memory Usage

During operation:
- Base daemon: ~200MB
- Database cache (dbcache): 450MB (configurable)
- Peer connections: ~50MB
- Transaction mempool: ~100-300MB
- **Total typical: 800MB - 1.2GB**

For compilation, 8GB RAM is recommended. Add swap if you have less:

```bash
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

## Cloud Provider Instances

| Provider | Instance | vCPUs | RAM | Est. Monthly |
|----------|----------|-------|-----|--------------|
| Hetzner | CPX41 | 8 | 16GB | ~$30-40 |
| OVH | B2-30 | 4 | 8GB | ~$40-50 |
| Vultr | High Freq 4 | 4 | 8GB | ~$60-80 |
| DigitalOcean | s-4vcpu-8gb | 4 | 8GB | ~$80-100 |
| AWS | t3.xlarge | 4 | 16GB | ~$120-150 |

> Best value: Hetzner and OVH for European locations.

## Self-Hosted VM (Proxmox/VMware)

```
VM Configuration:
├── CPU: 4 cores (host passthrough)
├── RAM: 8192 MB
├── Disk: 500GB (virtio-scsi, SSD backend)
├── Network: virtio, bridged
└── BIOS: UEFI (optional)
```

**Proxmox CLI example:**

```bash
qm create 200 \
  --name dogecoin-node \
  --cores 4 \
  --memory 8192 \
  --net0 virtio,bridge=vmbr0 \
  --scsihw virtio-scsi-pci \
  --scsi0 local-lvm:500,ssd=1 \
  --boot c --bootdisk scsi0
```

## Network Requirements

| Traffic | Bandwidth |
|---------|-----------|
| P2P Sync (initial) | 10-50 Mbps |
| P2P Steady State | 1-5 Mbps |
| RPC (Pool) | 1-10 Mbps |

**Required Ports:**
- `22556/tcp` - P2P (forward this)
- `22555/tcp` - RPC (localhost only for pools)
- `22/tcp` - SSH (restrict to your IP)

## Static IP Recommendation

For stable P2P connections, use a static IP:

**Option A: Static IP on VM**

```bash
# /etc/network/interfaces
auto eth0
iface eth0 inet static
    address 192.168.1.100
    netmask 255.255.255.0
    gateway 192.168.1.1
    dns-nameservers 1.1.1.1 8.8.8.8
```

**Option B: DHCP Reservation**

Create a DHCP reservation on your router for the VM's MAC address.

