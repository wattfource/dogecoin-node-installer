# Dogecoin Wallet Management

This guide covers creating and managing the Dogecoin wallet for your node.

## Creating Your Wallet

If the wallet wasn't created automatically during setup, create it manually:

```bash
# Create a new wallet
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf createwallet "pool-wallet"

# Get your pool address (SAVE THIS!)
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf -rpcwallet=pool-wallet getnewaddress "pool"
```

The address will start with `D` - this is your Dogecoin address for receiving payments.

### Verify Wallet Was Created

```bash
# List wallets
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf listwallets

# Should show: ["pool-wallet"]
```

## Where is My Wallet?

After creation, wallet files are stored securely:

| Item | Location |
|------|----------|
| Wallet files | `/var/lib/dogecoin/wallets/pool-wallet/` |
| Config (address, credentials) | `/etc/dogecoin/pool-wallet.conf` |
| Daemon config | `/etc/dogecoin/dogecoin.conf` |

## View Wallet Details

```bash
# View address and wallet info
sudo cat /etc/dogecoin/pool-wallet.conf
```

**Important:** This file contains sensitive information. Anyone with access can potentially control your funds.

## How the Pool Wallet Works

```
Miners submit shares → Pool finds block → Block reward → Your Pool Wallet
                                              ↓
                              Pool fee (your cut) stays in wallet
                              Miner payouts sent from wallet
```

The pool wallet:
1. **Receives** block rewards when the pool finds blocks
2. **Holds** your pool fee percentage  
3. **Sends** payouts to miners (configured in pool software)

## Dogecoin Address Types

Dogecoin primarily uses legacy addresses:

| Type | Description | Use Case |
|------|-------------|----------|
| **Legacy** | Original format (starts with D) | Standard, maximum compatibility |

The setup script creates legacy addresses by default for best compatibility.

## Accessing Your Wallet

### Check Wallet Balance

Once your node is synced:

```bash
# Check if node is synced first
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf getblockchaininfo | jq '{blocks, headers, sync: (if .blocks == .headers then "SYNCED" else "SYNCING" end)}'

# Check wallet balance
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf getbalance
```

### View Wallet Addresses

```bash
# List all addresses
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf listreceivedbyaddress 0 true

# Get new receiving address
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf getnewaddress "label"
```

### View Transaction History

```bash
# List recent transactions
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf listtransactions "*" 20

# Get transaction details
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf gettransaction "txid"
```

## Sending Dogecoin

### Basic Send

```bash
# Send to address
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf sendtoaddress "D..." 1000.0

# Send with comment
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf sendtoaddress "D..." 1000.0 "Payout"
```

### Batch Payouts (for pools)

```bash
# Send to multiple addresses in one transaction
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf sendmany "" '{"Daddr1": 500.0, "Daddr2": 1000.0, "Daddr3": 250.0}'
```

## Wallet Backup

### Export Wallet

```bash
# Backup wallet to file
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf backupwallet "/secure-backup/wallet-$(date +%Y%m%d).dat"
```

### Backup Wallet Files

```bash
# Backup entire wallet directory
sudo cp -r /var/lib/dogecoin/wallets/pool-wallet /secure-backup/dogecoin-wallet-backup-$(date +%Y%m%d)
```

### What to Backup

| Item | How to Backup | Recovery Method |
|------|---------------|-----------------|
| Wallet files | Copy `/var/lib/dogecoin/wallets/` | Replace directory |
| Individual keys | `dumpprivkey ADDRESS` | `importprivkey` |

## Wallet Restoration

### From Wallet Files

```bash
# Stop daemon
sudo systemctl stop dogecoind

# Restore wallet directory
sudo cp -r /secure-backup/dogecoin-wallet-backup /var/lib/dogecoin/wallets/pool-wallet
sudo chown -R dogecoin:dogecoin /var/lib/dogecoin/wallets

# Start daemon
sudo systemctl start dogecoind
```

### From Private Key

```bash
# Import private key
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf importprivkey "your-private-key" "label" true

# Rescan blockchain for transactions
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf rescanblockchain
```

## Security Best Practices

### 1. Backup Immediately After Setup

```bash
# Right after wallet creation, backup
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf backupwallet ~/dogecoin-wallet-backup-$(date +%Y%m%d).dat

# Store this file securely (encrypted USB, safe deposit box, etc.)
```

### 2. Restrict Config File Access

The setup script already does this, but verify:

```bash
# Check permissions (should be 600 = owner read/write only)
ls -la /etc/dogecoin/pool-wallet.conf
ls -la /etc/dogecoin/dogecoin.conf

# Fix if needed
sudo chmod 600 /etc/dogecoin/pool-wallet.conf
sudo chmod 600 /etc/dogecoin/dogecoin.conf
sudo chown dogecoin:dogecoin /etc/dogecoin/*.conf
```

### 3. Wallet Encryption

Encrypt your wallet with a passphrase:

```bash
# Encrypt wallet (you'll be prompted for passphrase)
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf encryptwallet "your-strong-passphrase"

# Note: This requires a daemon restart
# After encryption, you must unlock to send:
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf walletpassphrase "your-passphrase" 60
```

### 4. Separate Withdrawal Wallet

For larger operations, consider:
1. Pool wallet receives rewards
2. Periodically transfer to a "cold" wallet you control elsewhere
3. Keep only operational funds in the pool wallet

## Wallet Commands Reference

| Command | Description |
|---------|-------------|
| `getbalance` | Show confirmed balance |
| `getunconfirmedbalance` | Show unconfirmed balance |
| `getnewaddress` | Generate new receiving address |
| `listreceivedbyaddress` | List addresses with received amounts |
| `listtransactions` | Show transaction history |
| `sendtoaddress ADDR AMT` | Send DOGE to address |
| `sendmany "" {addrs}` | Send to multiple addresses |
| `backupwallet FILE` | Backup wallet to file |
| `listwallets` | Show loaded wallets |
| `loadwallet NAME` | Load a wallet |
| `unloadwallet NAME` | Unload a wallet |
| `encryptwallet PASS` | Encrypt wallet |
| `walletpassphrase PASS SEC` | Unlock wallet for SEC seconds |
| `walletlock` | Lock encrypted wallet |

## Address Format

Dogecoin addresses start with `D`:

| Format | Prefix | Example |
|--------|--------|---------|
| Legacy | D | `DH5yaieqoZN36fDVciNyRueRGvGLR3mr7L` |

## Troubleshooting

### "Wallet not found" Error

```bash
# List available wallets
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf listwallets

# Load wallet if not loaded
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf loadwallet "pool-wallet"
```

### "Wallet is not connected to daemon"

Your node isn't synced or isn't running:

```bash
# Check node status
sudo systemctl status dogecoind

# Check sync progress
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf getblockchaininfo | jq '.blocks, .headers'
```

### "Error opening wallet"

Possible causes:
- Wallet is already open in another process
- Corrupted wallet file
- Wrong wallet path

```bash
# Check for multiple processes
pgrep -a dogecoind

# Verify wallet exists
ls -la /var/lib/dogecoin/wallets/
```

### Wallet Shows 0 Balance After Sync

If your node just synced, transactions may not be visible yet:

```bash
# Rescan blockchain for wallet transactions
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf rescanblockchain

# Or rescan from specific height
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf rescanblockchain 1000000
```

## Mining Pool Integration

### Wallet Address for Pool Software

```bash
# Get the primary receiving address
PRIMARY_ADDR=$(dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf getnewaddress "pool-rewards")
echo "Pool Rewards Address: $PRIMARY_ADDR"

# Add to pool software configuration
```

### Checking Block Rewards

```bash
# List coinbase (mining) transactions
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf listtransactions "*" 100 | jq '[.[] | select(.category == "generate" or .category == "immature")]'
```

## Next Steps

Once your node is synced:
1. Verify wallet address matches pool software config
2. Test a small transaction
3. Set up wallet backup automation
4. Configure pool software payout settings
5. Monitor wallet balance for block rewards

