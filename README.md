# Dogecoin Node Setup for Debian 13

Interactive setup script for deploying Dogecoin nodes on Debian 13, supporting both personal use and mining pool backends.

## Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| RAM | 4GB | 8GB |
| Disk (Full + txindex) | 400GB SSD | 500GB SSD |
| Disk (Pruned) | 20GB | 50GB |
| CPU | 2 cores | 4 cores |
| OS | Debian 13 (Trixie) | |

> **⚠️ Blockchain size (Dec 2024):** ~265 GB. With txindex for mining pools: ~330-360 GB.

> **Note:** Mining pools require SSD storage. See [VM Requirements](docs/VM-REQUIREMENTS.md) for details.

## Quick Start

### One-Liner Install

```bash
sudo apt update && sudo apt install -y git curl && rm -rf /tmp/dogecoin-setup && git clone https://github.com/wattfource/dogecoin-node-installer.git /tmp/dogecoin-setup && cd /tmp/dogecoin-setup && chmod +x setup-dogecoin.sh && sudo ./setup-dogecoin.sh
```

### Manual Install

```bash
git clone https://github.com/wattfource/dogecoin-node-installer.git
cd dogecoin-node-installer
sudo ./setup-dogecoin.sh
```

## Setup Options

The interactive wizard guides you through:

| Step | Options |
|------|---------|
| **Node Type** | Standard (personal) or Mining Pool Backend |
| **Blockchain** | Full (~100GB) or Pruned (~4GB) |
| **Network** | RPC binding, firewall rules |
| **Pool Wallet** | Create new or use existing (pool mode) |

## After Installation

```bash
# Check status
sudo systemctl status dogecoind

# View sync progress
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf getblockchaininfo

# View logs
sudo journalctl -u dogecoind -f

# Re-run setup (update/reconfigure)
sudo ./setup-dogecoin.sh
```

## Port Forwarding

| Port | Purpose | Forward? |
|------|---------|----------|
| **22556** | P2P network | **Yes** - required |
| 22555 | RPC | No (localhost only for pools) |
| 28332/28333 | ZMQ | No (localhost only) |

See [Firewall Guide](docs/FIREWALL.md) for router configuration.

## Uninstall

### Complete Removal (One-Liner)

Downloads a fresh uninstall script and removes **everything** installed by the setup script:

```bash
rm -rf /tmp/dogecoin-setup && git clone https://github.com/wattfource/dogecoin-node-installer.git /tmp/dogecoin-setup && sudo /tmp/dogecoin-setup/uninstall-dogecoin.sh --force && rm -rf /tmp/dogecoin-setup
```

### Interactive Uninstall

For more control over what gets removed:

```bash
# Download fresh and run interactively
rm -rf /tmp/dogecoin-setup && git clone https://github.com/wattfource/dogecoin-node-installer.git /tmp/dogecoin-setup && sudo /tmp/dogecoin-setup/uninstall-dogecoin.sh
```

### Uninstall Options

```bash
# Keep blockchain data (faster reinstall)
sudo ./uninstall-dogecoin.sh --keep-blockchain

# Keep wallet files only
sudo ./uninstall-dogecoin.sh --keep-wallets

# Silent complete removal (no prompts)
sudo ./uninstall-dogecoin.sh --force --quiet
```

## File Locations

| Path | Description |
|------|-------------|
| `/opt/dogecoin/` | Binaries |
| `/var/lib/dogecoin/` | Blockchain data |
| `/etc/dogecoin/dogecoin.conf` | Configuration |
| `/var/log/dogecoin/` | Logs |

## Documentation

| Guide | Description |
|-------|-------------|
| [Mining Pool Setup](docs/MINING-POOL.md) | Pool-specific configuration and RPC methods |
| [VM Requirements](docs/VM-REQUIREMENTS.md) | Detailed specifications and cloud providers |
| [Wallet Management](docs/WALLET.md) | Wallet creation, CLI, backups, security |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | Common issues and fixes |
| [Firewall Setup](docs/FIREWALL.md) | Port forwarding for different routers |
| [Lessons Learned](docs/LESSONS-LEARNED.md) | Build insights for Debian 13 |

## Resources

- [Dogecoin Website](https://dogecoin.com/)
- [Dogecoin GitHub](https://github.com/dogecoin/dogecoin)

## License

MIT License

