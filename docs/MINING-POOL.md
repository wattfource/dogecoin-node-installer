# Mining Pool Configuration

Guide for setting up a Dogecoin node as a mining pool backend.

## Overview

When you select **Mining Pool Backend** during setup, the script configures:

- `txindex=1` - Transaction index for pool lookups
- `rpcbind=127.0.0.1` - RPC on localhost only (secure)
- `maxconnections=256` - Higher connection limits
- Block notification options (RPC polling, ZMQ, or blocknotify)

## Pool Software Connection

```
RPC Endpoint:  http://127.0.0.1:22555
RPC User:      (configured during setup)
RPC Password:  (configured during setup)
```

View your credentials:

```bash
grep -E "rpcuser|rpcpassword" /etc/dogecoin/dogecoin.conf
```

## Block Notification Methods

### Option 1: RPC Polling (Recommended)

Most compatible method. Pool software polls for new blocks:

```bash
# Poll every 1-2 seconds
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf getbestblockhash
```

No additional configuration needed.

### Option 2: ZMQ Notifications

Instant push notifications (may have compatibility issues):

```
ZMQ Hashblock: tcp://127.0.0.1:28332
ZMQ Rawblock:  tcp://127.0.0.1:28333
```

If ZMQ causes problems, disable it:

```bash
sudo sed -i 's/^zmqpub/#zmqpub/' /etc/dogecoin/dogecoin.conf
sudo systemctl restart dogecoind
```

### Option 3: blocknotify Script

Runs a command on each new block:

```ini
# In dogecoin.conf
blocknotify=curl -s http://localhost:8000/newblock/%s
```

## Key RPC Methods

| Method | Description |
|--------|-------------|
| `getblocktemplate` | Get work for miners |
| `submitblock` | Submit found blocks |
| `getbestblockhash` | Check for new blocks |
| `getblockchaininfo` | Node sync status |
| `validateaddress` | Validate miner addresses |
| `getblock` | Get block by hash |
| `getblockhash` | Get hash by height |

## Test Commands

```bash
# Check node sync status
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf getblockchaininfo

# Get block template for mining
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf getblocktemplate

# Check current best block
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf getbestblockhash

# Get mining info
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf getmininginfo

# Validate an address
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf validateaddress "D..."
```

## Pool Wallet

View wallet configuration:

```bash
sudo cat /etc/dogecoin/pool-wallet.conf
```

See [Wallet Management](WALLET.md) for wallet operations.

## Example Configuration

```ini
# /etc/dogecoin/dogecoin.conf (Mining Pool Mode)

datadir=/var/lib/dogecoin
listen=1
port=22556

# RPC (localhost only)
server=1
rpcuser=poolrpc
rpcpassword=your-secure-password
rpcbind=127.0.0.1
rpcport=22555
rpcallowip=127.0.0.1

# Mining Pool Settings
txindex=1
maxconnections=256

# ZMQ (optional)
# zmqpubhashblock=tcp://127.0.0.1:28332
# zmqpubrawblock=tcp://127.0.0.1:28333

# Performance
dbcache=450
par=4

# Security
upnp=0
```

## Recommended Pool Software

- **[NOMP](https://github.com/zone117x/node-open-mining-portal)** - Node.js Open Mining Portal
- **[open-dogecoin-pool](https://github.com/nicehash/open-litecoin-pool)** - Go-based stratum server (adaptable for Dogecoin)
- **[MPOS](https://github.com/MPOS/php-mpos)** - PHP Mining Portal

## Multi-Coin Architecture

```
┌─────────────────────────────────────┐
│       Pool Frontend + Database      │
└──────────────────┬──────────────────┘
                   │
     ┌─────────────┼─────────────┐
     ▼             ▼             ▼
┌─────────┐  ┌─────────┐  ┌─────────┐
│  DOGE   │  │   LTC   │  │   BTC   │
│ Stratum │  │ Stratum │  │ Stratum │
│ + Node  │  │ + Node  │  │ + Node  │
└─────────┘  └─────────┘  └─────────┘
```

Each coin needs its own node and stratum server.

## Algorithm Info

- **Algorithm:** Scrypt
- **Block Time:** ~1 minute
- **Merged Mining:** Compatible with Litecoin (AuxPoW)

> **Note:** Dogecoin supports merged mining with Litecoin, allowing miners to mine both coins simultaneously.

## Troubleshooting

### Node not synced

Pool won't work until fully synced:

```bash
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf getblockchaininfo | grep -E "blocks|headers|verificationprogress"
```

### RPC connection refused

1. Check service is running: `sudo systemctl status dogecoind`
2. Check config: `grep rpc /etc/dogecoin/dogecoin.conf`
3. Check port: `sudo ss -tlnp | grep 22555`

### getblocktemplate fails

Ensure node is fully synced and txindex is enabled:

```bash
grep txindex /etc/dogecoin/dogecoin.conf
# Should show: txindex=1
```

