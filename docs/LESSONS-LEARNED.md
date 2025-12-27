# Lessons Learned: Building Dogecoin on Debian 13

This document captures lessons learned while developing the Dogecoin node installer for Debian 13 (Trixie).

## Key Findings

### 1. Berkeley DB Version Requirements

**Problem:** Dogecoin v1.14.9 with `--with-incompatible-bdb` requires BDB 5.3+, not BDB 4.8.

**What we tried:**
- Building BDB 4.8.30 from source (like Bitcoin/Litecoin traditionally required)
- Various configure flags: `BDB_LIBS`, `BDB_CFLAGS`, `CPPFLAGS`, `LDFLAGS`
- Exporting environment variables before configure
- Creating symlinks to `/usr/local`

**Solution:** Use system BDB from `libdb5.3++-dev` package instead of compiling BDB 4.8.

```bash
# What works on Debian 13:
apt-get install -y libdb5.3++-dev libdb5.3-dev

# Configure with:
./configure --with-incompatible-bdb ...
```

**Key insight:** The configure check explicitly requires BDB 5.3+:
```c
#if !((DB_VERSION_MAJOR == 5 && DB_VERSION_MINOR >= 3) || DB_VERSION_MAJOR > 5)
  #error "failed to find bdb 5.3+"
#endif
```

### 2. Dogecoin vs Bitcoin/Litecoin Differences

| Feature | Bitcoin/Litecoin | Dogecoin v1.14.9 |
|---------|------------------|------------------|
| BDB Version | 4.8 (legacy) | 5.3+ required |
| SegWit | Supported | Not supported |
| createwallet syntax | Multiple params | Simple (name only) |
| getnewaddress | Needs address type | No type param needed |

### 3. Package Names on Debian 13

The BDB package names vary:
- `libdb5.3++-dev` - Debian 13 specific
- `libdb++-dev` - Generic (may not exist)

**Solution:** Try specific version first, fall back to generic:
```bash
apt-get install -y libdb5.3++-dev libdb5.3-dev 2>/dev/null || \
apt-get install -y libdb++-dev libdb-dev
```

### 4. GCC 14 Compatibility

Dogecoin v1.14.6 had compilation issues with GCC 14 (Debian 13's default).

**Solution:** Use v1.14.9 which has better modern compiler support, plus:
```bash
CXXFLAGS="-O2 -Wno-error"
```

### 5. Wallet Creation Syntax

Dogecoin v1.14.x uses simpler RPC syntax than newer Bitcoin:

```bash
# Bitcoin-style (doesn't work on Dogecoin 1.14.x):
createwallet "name" false false "" false false

# Dogecoin-style (works):
createwallet "name"
```

### 6. No SegWit Support

Dogecoin does not support SegWit. Remove any SegWit references:

```bash
# Wrong:
getblocktemplate '{"rules":["segwit"]}'

# Correct:
getblocktemplate
```

## Build Dependencies

Official Dogecoin v1.14.9 dependencies from `doc/build-unix.md`:

**Required:**
```bash
apt-get install build-essential libtool autotools-dev automake pkg-config \
    bsdmainutils libssl-dev libevent-dev \
    libboost-system-dev libboost-filesystem-dev libboost-chrono-dev \
    libboost-program-options-dev libboost-test-dev libboost-thread-dev
```

**Optional:**
```bash
apt-get install libzmq3-dev libminiupnpc-dev libdb5.3++-dev
```

## Configuration Tips

### Mining Pool Mode

Essential settings for pool backend:
```ini
txindex=1              # Required for pool lookups
server=1               # Enable RPC
rpcbind=127.0.0.1     # Localhost only (secure)
maxconnections=256     # Higher for pools
```

### Network Ports

| Port | Purpose | Expose? |
|------|---------|---------|
| 22556 | P2P | Yes (port forward) |
| 22555 | RPC | No (localhost) |
| 28332 | ZMQ hashblock | No (localhost) |
| 28333 | ZMQ rawblock | No (localhost) |

## Debugging Tips

### Check Configure Failures

When configure fails, check `config.log` for the actual test that failed:
```bash
grep -i -B2 -A10 "error:" /usr/local/src/dogecoin/config.log
```

### Verify BDB Installation

```bash
# Check header exists
ls -la /usr/include/db_cxx.h

# Check library exists
ls -la /usr/lib/x86_64-linux-gnu/libdb_cxx*.so

# Check version
grep DB_VERSION /usr/include/db.h | head -3
```

### Wallet Troubleshooting

```bash
# List wallets
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf listwallets

# Load wallet if needed
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf loadwallet "pool-wallet"

# Create if missing
dogecoin-cli -conf=/etc/dogecoin/dogecoin.conf createwallet "pool-wallet"
```

### 7. Blockchain Size - Don't Trust Third-Party Stats

**Problem:** Third-party blockchain explorers (bitinfocharts, etc.) reported Dogecoin blockchain as ~65 GB, but actual sync showed ~265 GB.

**Real-world data from sync (Dec 2024):**
```
"size_on_disk": 99609676692  → 99.6 GB at 37.6% sync
Full estimate: 99.6 / 0.376 = ~265 GB
```

**Lesson:** Always provision based on actual sync data, not third-party estimates. Those sites may report compressed sizes or different metrics.

**Correct storage requirements:**
| Component | Size |
|-----------|------|
| Full Blockchain | ~265 GB |
| Transaction Index | ~50-80 GB |
| **Total (mining pool)** | **~330-360 GB** |
| **Recommended** | **400-500 GB** |

## Resources

- [Dogecoin GitHub](https://github.com/dogecoin/dogecoin)
- [Official Build Docs](https://github.com/dogecoin/dogecoin/blob/v1.14.9/doc/build-unix.md)
- [Dogecoin v1.14.9 Release](https://github.com/dogecoin/dogecoin/releases/tag/v1.14.9)

## Version History

| Installer Version | Dogecoin Version | Notes |
|-------------------|------------------|-------|
| 1.0.0 | v1.14.9 | Initial release, BDB 5.3+ |

---

*Last updated: December 2024*

