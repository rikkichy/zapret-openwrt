# zapret Discord + YouTube for OpenWrt/Linux (nfqws)

Adapted from [zapret-discord-youtube-windows](https://github.com/Flowseal/zapret-discord-youtube) for OpenWrt routers using `nfqws`.

## Quick Start (Recommended)

Upload this entire `zapret-openwrt-discord-youtube` folder to your router (e.g. via `scp`) and run:

```sh
chmod +x service.sh
./service.sh
```

The interactive manager will guide you through setup: copying lists, installing a strategy, and starting zapret. Similar to `service.bat` on Windows.

## Prerequisites

- OpenWrt router with zapret v72.10+ installed (from `zapret-v72.10-openwrt-embedded.tar.gz`)
- `ZAPRET_BASE` is the zapret installation directory (typically `/opt/zapret`)

## Manual Installation

### 1. Copy domain lists

```sh
cp lists/list-general.txt   $ZAPRET_BASE/ipset/
cp lists/list-google.txt    $ZAPRET_BASE/ipset/
cp lists/list-exclude.txt   $ZAPRET_BASE/ipset/
cp lists/ipset-exclude.txt  $ZAPRET_BASE/ipset/
```

### 2. Copy extra fake-packet binaries

These two files are not included in the standard zapret distribution:

```sh
cp files/fake/tls_clienthello_4pda_to.bin  $ZAPRET_BASE/files/fake/
cp files/fake/tls_clienthello_max_ru.bin   $ZAPRET_BASE/files/fake/
```

The following files are already present in zapret (no copy needed):
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

### 4. Restart zapret

**OpenWrt:**
```sh
/etc/init.d/zapret restart
```

**Linux (systemd):**
```sh
systemctl restart zapret
```

## Available Strategies

Start with `50-discord-youtube` (general). If it doesn't work for your ISP, try alternatives:

| File | Description |
|------|-------------|
| `50-discord-youtube` | **Default.** TCP multisplit with sequence overlap |
| `50-discord-youtube-alt1` | fake+fakedsplit, fooling=ts |
| `50-discord-youtube-alt2` | multisplit, seqovl=652, split-pos=2 |
| `50-discord-youtube-alt3` | fake+hostfakesplit with SNI spoofing |
| `50-discord-youtube-alt4` | fake+multisplit, fooling=badseq |
| `50-discord-youtube-alt5` | syndata+multidisorder (NOT RECOMMENDED) |
| `50-discord-youtube-alt6` | multisplit, seqovl=681 (google pattern only) |
| `50-discord-youtube-alt7` | multisplit, split-pos=sniext+1 |
| `50-discord-youtube-alt8` | fake with fake-tls-mod=none, fooling=badseq |
| `50-discord-youtube-alt9` | hostfakesplit, fooling=ts+md5sig |
| `50-discord-youtube-alt10` | fake with multiple TLS fakes, fooling=ts |
| `50-discord-youtube-alt11` | fake+multisplit, high repeats (8-11) |
| `50-discord-youtube-simple-fake` | Simple fake packets, fooling=ts |
| `50-discord-youtube-simple-fake-alt1` | Simple fake, fooling=badseq |
| `50-discord-youtube-simple-fake-alt2` | Simple fake, fooling=ts (variant) |
| `50-discord-youtube-faketls` | Auto-generated TLS fakes, multidisorder |
| `50-discord-youtube-faketls-alt1` | Auto TLS fakes, fakedsplit |
| `50-discord-youtube-faketls-alt2` | Auto TLS fakes, multisplit+seqovl |
| `50-discord-youtube-faketls-alt3` | Auto TLS fakes, fooling=ts |

## Switching Strategies

The easiest way is to use `./service.sh` and choose option 1 (Install Strategy).

Or manually:

1. Remove the current script from custom.d:
```sh
rm $ZAPRET_BASE/init.d/openwrt/custom.d/50-discord-youtube*
```

2. Copy a different strategy:
```sh
cp strategies/50-discord-youtube-alt1 $ZAPRET_BASE/init.d/openwrt/custom.d/
```

3. Restart zapret:
```sh
/etc/init.d/zapret restart
```

## What These Scripts Do

Each strategy runs a single `nfqws` daemon with a multi-rule filter chain:

1. **QUIC UDP 443** - Fake packets for Discord/Cloudflare QUIC traffic (hostlist-filtered)
2. **Discord Voice UDP 19294-50100** - Fake packets for Discord voice and STUN
3. **Discord.media TCP 2053,2083,2087,2096,8443** - Desync for Discord media on Cloudflare ports
4. **YouTube TCP 443** - Desync for YouTube/Google video traffic
5. **General TCP 80,443** - Desync for Discord/Cloudflare web traffic (hostlist-filtered)

Firewall rules (iptables or nftables) redirect matching packets to NFQUEUE, where `nfqws` applies the desync techniques.

## Customization

### Adding domains

Edit `$ZAPRET_BASE/ipset/list-general.txt` to add domains for rule 1 and 5.
Edit `$ZAPRET_BASE/ipset/list-google.txt` to add domains for rule 4.

### Excluding domains

Edit `$ZAPRET_BASE/ipset/list-exclude.txt` to prevent bypass on specific domains.

### Overriding options via config

All variables can be overridden in the zapret config file without editing the custom.d script:

```sh
# In config file, override the nfqws options:
NFQWS_DSCYT_OPT="--filter-udp=443 --dpi-desync=fake --dpi-desync-repeats=6 --new --filter-tcp=443 --dpi-desync=multisplit"

# Override port lists:
NFQWS_DSCYT_PORTS_TCP="80,443"
NFQWS_DSCYT_PORTS_UDP="443"
```

## Troubleshooting

- **No effect:** Try a different strategy. DPI behavior varies by ISP and region.
- **Connectivity issues:** Check that `list-exclude.txt` contains domains you need unmodified access to.
- **Check logs:** Run `nfqws` manually with `--debug` flag to see what packets are being processed.
- **IPv6:** IPv6 is disabled by default in config (`DISABLE_IPV6=1`). Enable if your network uses it.

## Translation from Windows (winws) to Linux (nfqws)

| Windows (winws) | Linux (nfqws) |
|-----------------|---------------|
| `winws.exe` | `nfqws` binary (via `do_nfqws`) |
| `--wf-tcp=...` | iptables/nftables rules (in firewall functions) |
| `--wf-udp=...` | iptables/nftables rules (in firewall functions) |
| `%BIN%file.bin` | `$ZAPRET_BASE/files/fake/file.bin` |
| `%LISTS%list.txt` | `$ZAPRET_BASE/ipset/list.txt` |
| All other flags | Identical between winws and nfqws |
