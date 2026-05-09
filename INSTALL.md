# zapret2 Discord + YouTube for OpenWrt/Linux (nfqws2)

Adapted from [zapret-discord-youtube-windows](https://github.com/Flowseal/zapret-discord-youtube) for OpenWrt routers, running on top of [zapret v2](https://github.com/bol-van/zapret2) (`nfqws2`).

## One-Command Install (Recommended)

Run this on your OpenWrt router via SSH:

```sh
uclient-fetch -O- https://raw.githubusercontent.com/rikkichy/zapret-openwrt/main/install.sh | sh
```

Alternative (if `uclient-fetch` is not available):

```sh
wget -O- https://raw.githubusercontent.com/rikkichy/zapret-openwrt/main/install.sh | sh
```

This downloads the repo, extracts it, and launches the interactive service manager. From the menu you can:
- Install zapret2 base from the [latest GitHub release](https://github.com/bol-van/zapret2/releases) (the `*-openwrt-embedded.tar.gz` asset)
- Pick a strategy
- Copy the lists and custom blob files into place
- Restart the daemon

## Manual Install

If you prefer, upload this entire folder to your router (e.g. via `scp`) and run:

```sh
chmod +x service.sh
./service.sh
```

## Prerequisites

- OpenWrt router with **zapret v2** installed (from the official `zapret2-vX.Y.Z.W-openwrt-embedded.tar.gz` release).
- `ZAPRET_BASE` is the zapret2 installation directory (typically `/opt/zapret2`).
- `service.sh` can fetch and run the v2 installer for you (it queries the GitHub API for the latest release; override the version with `ZAPRET2_VERSION=vX.Y.Z.W ./service.sh`).

## Manual Installation

### 1. Copy domain and IP lists

```sh
cp lists/list-general.txt   $ZAPRET_BASE/ipset/
cp lists/list-google.txt    $ZAPRET_BASE/ipset/
cp lists/list-exclude.txt   $ZAPRET_BASE/ipset/
cp lists/ipset-exclude.txt  $ZAPRET_BASE/ipset/
cp lists/ipset-all.txt      $ZAPRET_BASE/ipset/
```

### 2. Copy extra fake-packet binaries

These three blobs are not in the standard zapret2 distribution:

```sh
cp files/fake/tls_clienthello_4pda_to.bin    $ZAPRET_BASE/files/fake/
cp files/fake/tls_clienthello_max_ru.bin     $ZAPRET_BASE/files/fake/
cp files/fake/quic_initial_dbankcloud_ru.bin $ZAPRET_BASE/files/fake/
```

The following blobs ship with zapret2 (no copy needed):
- `tls_clienthello_www_google_com.bin`
- `quic_initial_www_google_com.bin`
- `stun.bin`

### 3. Choose and install a strategy

Pick ONE strategy file and copy it to the custom.d directory:

**For OpenWrt:**
```sh
cp strategies/50-discord-youtube $ZAPRET_BASE/init.d/openwrt/custom.d/
```

**For Linux (sysv init):**
```sh
cp strategies/50-discord-youtube $ZAPRET_BASE/init.d/sysv/custom.d/
```

### 4. Restart zapret2

**OpenWrt:**
```sh
/etc/init.d/zapret2 restart
```

**Linux (systemd):**
```sh
systemctl restart zapret2
```

## Available Strategies

Start with `50-discord-youtube` (general). If it doesn't work for your ISP, try alternatives. Behavior is described in v2 terms (`--lua-desync=fn:args`):

| File | Description |
|------|-------------|
| `50-discord-youtube` | **Default.** TCP `multisplit` with sequence overlap (seqovl=681) |
| `50-discord-youtube-alt1` | `fake` + `fakedsplit`, `tcp_ts=10000` fooling, zero pattern |
| `50-discord-youtube-alt2` | `multisplit`, seqovl=652, pos=3 |
| `50-discord-youtube-alt3` | `fake` + `hostfakesplit` with SNI spoofing (`tls_mod`) |
| `50-discord-youtube-alt4` | `fake` + `multisplit`, `tcp_seq=1000` fooling |
| `50-discord-youtube-alt5` | `syndata` + `multidisorder` (NOT RECOMMENDED — IPv4 only, simplified) |
| `50-discord-youtube-alt6` | `multisplit`, seqovl=681, uses google pattern for general TCP |
| `50-discord-youtube-alt7` | `multisplit`, pos=`3,sniext+1` (multi-pos), seqovl=679; `syndata` for catch-all |
| `50-discord-youtube-alt8` | `fake` only, `tcp_seq=2` fooling |
| `50-discord-youtube-alt9` | `hostfakesplit`, `tcp_ts=10000` (+ `tcp_md5` on general) |
| `50-discord-youtube-alt10` | `fake` with multiple TLS blobs, `tcp_ts=10000` |
| `50-discord-youtube-alt11` | `fake` + `multisplit`, high repeats (8-11), `tcp_ts=10000` |
| `50-discord-youtube-simple-fake` | Simple `fake` packets, `tcp_ts=10000` |
| `50-discord-youtube-simple-fake-alt1` | Simple `fake`, `tcp_seq=2` |
| `50-discord-youtube-simple-fake-alt2` | Simple `fake`, `tcp_ts=10000` (variant) |
| `50-discord-youtube-faketls` | TLS fakes with SNI spoofing + `multidisorder`, `tcp_seq=-10000` |
| `50-discord-youtube-faketls-alt1` | TLS fakes with SNI spoofing + `fakedsplit`, `tcp_seq=2` |
| `50-discord-youtube-faketls-alt2` | TLS fakes + `multisplit`+seqovl, `tcp_seq=10000000` |
| `50-discord-youtube-faketls-alt3` | TLS fakes + `multisplit`+seqovl, `tcp_ts=10000` |

## Switching Strategies

Easiest: `./service.sh` and choose option 1 (Install Strategy).

Or manually:

1. Remove the current strategy from custom.d:
   ```sh
   rm $ZAPRET_BASE/init.d/openwrt/custom.d/50-discord-youtube*
   ```
2. Copy a different strategy:
   ```sh
   cp strategies/50-discord-youtube-alt1 $ZAPRET_BASE/init.d/openwrt/custom.d/
   ```
3. Restart zapret2:
   ```sh
   /etc/init.d/zapret2 restart
   ```

## What These Scripts Do

Each strategy runs a single `nfqws2` daemon with a multi-rule filter chain (separated by `--new`). All custom fake blobs are registered up-front via `--blob=NAME:@PATH` and referenced by short name in `--lua-desync=fake:blob=NAME`.

1. **QUIC UDP 443** — fake QUIC initial for Discord/Cloudflare QUIC traffic (hostlist-filtered)
2. **Discord Voice UDP 19294-50100** — fake QUIC for Discord voice and STUN with custom dbankcloud blob
3. **Discord.media TCP 2053,2083,2087,2096,8443** — desync for Discord media on Cloudflare ports
4. **YouTube TCP 443** — desync for YouTube/Google video traffic
5. **General TCP 80,443** — desync for Discord/Cloudflare web traffic (hostlist-filtered)
6. **Catch-all UDP 443** — same desync as rule 1, matched by IP via `ipset-all.txt`
7. **Catch-all TCP 80,443,8443** — same desync as rule 5, matched by IP via `ipset-all.txt`

Firewall rules (iptables or nftables) redirect matching packets to NFQUEUE, where `nfqws2` invokes the Lua desync functions on the captured payload.

## Customization

### Adding domains

Edit `$ZAPRET_BASE/ipset/list-general.txt` to add domains for rules 1 and 5.
Edit `$ZAPRET_BASE/ipset/list-google.txt` to add domains for rule 4.

### Excluding domains

Edit `$ZAPRET_BASE/ipset/list-exclude.txt` to prevent bypass on specific domains.

### Overriding options via config

All variables can be overridden in the zapret2 config file without editing the custom.d script:

```sh
# In config file, override the nfqws2 options:
NFQWS_DSCYT_OPT="--filter-udp=443 --lua-desync=fake:blob=fake_default_quic:repeats=6 --new --filter-tcp=443 --lua-desync=multisplit"

# Override port lists:
NFQWS_DSCYT_PORTS_TCP="80,443"
NFQWS_DSCYT_PORTS_UDP="443"
```

## Troubleshooting

- **No effect:** try a different strategy. DPI behavior varies by ISP and region.
- **Connectivity issues:** check `list-exclude.txt` contains domains you need unmodified.
- **Validate args:** `nfqws2 --dry-run --qnum=300 --lua-init=@$ZAPRET_BASE/lua/zapret-lib.lua --lua-init=@$ZAPRET_BASE/lua/zapret-antidpi.lua $NFQWS_DSCYT_OPT` — should print `command line parameters verified`.
- **Logs:** `logread | grep -i nfqws2` (OpenWrt) or `journalctl -u zapret2 -f` (systemd).
- **IPv6:** disabled by default in v2 config (`DISABLE_IPV6=1`). Enable if your network uses it.

## Translation from v1 (nfqws) to v2 (nfqws2)

| zapret v1 | zapret v2 |
|-----------|-----------|
| `nfqws` binary | `nfqws2` binary |
| `--dpi-desync=fake` | `--lua-desync=fake:blob=NAME` |
| `--dpi-desync=multisplit` | `--lua-desync=multisplit:pos=N:seqovl=N:seqovl_pattern=NAME` |
| `--dpi-desync=hostfakesplit` | `--lua-desync=hostfakesplit:host=NAME` |
| `--dpi-desync-fake-{tls,quic,http,discord,stun}=PATH` | `--blob=NAME:@PATH` (once) + `--lua-desync=fake:blob=NAME` |
| `--dpi-desync-split-pos=N` | `:pos=N+1` (v2 splits *at* position; v1 splits *after* N bytes) |
| `--dpi-desync-split-seqovl=N` | `:seqovl=N` |
| `--dpi-desync-split-seqovl-pattern=PATH` | `--blob=NAME:@PATH` + `:seqovl_pattern=NAME` |
| `--dpi-desync-fake-tls-mod=rnd,dupsid,sni=X` | `:tls_mod=rnd,dupsid,sni=X` |
| `--dpi-desync-fooling=ts` | `:tcp_ts=10000` (or `:tcp_ts_up`) |
| `--dpi-desync-fooling=badseq` | `:tcp_seq=-10000` |
| `--dpi-desync-fooling=md5sig` | `:tcp_md5` |
| `--dpi-desync-repeats=N` | `:repeats=N` |
| `--dpi-desync-ttl=N` | `:ip_ttl=N` / `:ip6_ttl=N` |
| `--ip-id=zero` (global) | `:ip_id=zero` (per-instance) |
| `--filter-tcp/udp/l3/l7`, `--hostlist*`, `--ipset*`, `--new`, `--qnum=` | unchanged |
| Combined modes (`fake,multisplit`) | Two `--lua-desync=` calls in the same profile |
