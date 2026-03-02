#!/bin/sh
# ZAPRET DISCORD+YOUTUBE SERVICE MANAGER for OpenWrt/Linux
# POSIX sh compatible (works with ash/busybox on OpenWrt)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Colors ---
if [ -t 1 ]; then
    C_GREEN='\033[0;32m'
    C_RED='\033[0;31m'
    C_YELLOW='\033[0;33m'
    C_CYAN='\033[0;36m'
    C_BOLD='\033[1m'
    C_RESET='\033[0m'
else
    C_GREEN='' C_RED='' C_YELLOW='' C_CYAN='' C_BOLD='' C_RESET=''
fi

print_ok()   { printf "${C_GREEN}[OK]${C_RESET} %s\n" "$1"; }
print_fail() { printf "${C_RED}[X]${C_RESET}  %s\n" "$1"; }
print_warn() { printf "${C_YELLOW}[?]${C_RESET} %s\n" "$1"; }
print_info() { printf "${C_CYAN}::${C_RESET}  %s\n" "$1"; }

pause_prompt() {
    printf "\nPress Enter to continue..."; read dummy </dev/tty
}

# --- Detect environment ---
detect_zapret_base() {
    if [ -n "$ZAPRET_BASE" ] && [ -d "$ZAPRET_BASE" ]; then
        return 0
    fi
    for d in /opt/zapret /usr/lib/zapret /etc/zapret; do
        if [ -d "$d" ] && [ -f "$d/config" -o -f "$d/config.default" ]; then
            ZAPRET_BASE="$d"
            return 0
        fi
    done
    # not found
    ZAPRET_BASE=""
    return 1
}

detect_custom_d() {
    CUSTOM_D=""
    if [ -z "$ZAPRET_BASE" ]; then return 1; fi
    if [ -d "$ZAPRET_BASE/init.d/openwrt/custom.d" ]; then
        CUSTOM_D="$ZAPRET_BASE/init.d/openwrt/custom.d"
    elif [ -d "$ZAPRET_BASE/init.d/sysv/custom.d" ]; then
        CUSTOM_D="$ZAPRET_BASE/init.d/sysv/custom.d"
    fi
    [ -n "$CUSTOM_D" ]
}

detect_init_system() {
    INIT_TYPE=""
    INIT_SCRIPT=""
    if [ -x "/etc/init.d/zapret" ]; then
        INIT_TYPE="initd"
        INIT_SCRIPT="/etc/init.d/zapret"
    elif [ -n "$ZAPRET_BASE" ] && [ -x "$ZAPRET_BASE/init.d/openwrt/zapret" ]; then
        INIT_TYPE="initd"
        INIT_SCRIPT="$ZAPRET_BASE/init.d/openwrt/zapret"
    elif [ -n "$ZAPRET_BASE" ] && [ -f "$ZAPRET_BASE/init.d/openwrt/zapret" ]; then
        INIT_TYPE="initd"
        INIT_SCRIPT="$ZAPRET_BASE/init.d/openwrt/zapret"
        chmod +x "$INIT_SCRIPT"
    elif command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files zapret.service >/dev/null 2>&1; then
        INIT_TYPE="systemd"
    elif [ -n "$ZAPRET_BASE" ] && [ -x "$ZAPRET_BASE/init.d/sysv/zapret" ]; then
        INIT_TYPE="sysv"
        INIT_SCRIPT="$ZAPRET_BASE/init.d/sysv/zapret"
    fi
}

zapret_cmd() {
    # $1 = start|stop|restart
    case "$INIT_TYPE" in
        initd|sysv) "$INIT_SCRIPT" "$1" ;;
        systemd)    systemctl "$1" zapret ;;
        *)
            print_fail "Cannot find zapret init script"
            print_info "Searched: /etc/init.d/zapret, $ZAPRET_BASE/init.d/openwrt/zapret"
            return 1
            ;;
    esac
}

# --- Active strategy ---
get_active_strategy() {
    ACTIVE_STRATEGY="none"
    ACTIVE_FILE=""
    if [ -z "$CUSTOM_D" ]; then return; fi
    for f in "$CUSTOM_D"/50-discord-youtube*; do
        [ -f "$f" ] || continue
        ACTIVE_FILE="$f"
        # Read strategy name from comment "# Strategy: ..."
        ACTIVE_STRATEGY=$(sed -n 's/^# Strategy: *//p' "$f" | head -1)
        [ -z "$ACTIVE_STRATEGY" ] && ACTIVE_STRATEGY="$(basename "$f")"
        return
    done
}

# --- Strategy listing ---
list_strategies() {
    STRAT_COUNT=0
    for f in "$SCRIPT_DIR/strategies"/50-discord-youtube*; do
        [ -f "$f" ] || continue
        STRAT_COUNT=$((STRAT_COUNT + 1))
        name=$(sed -n 's/^# Strategy: *//p' "$f" | head -1)
        fname=$(basename "$f")
        [ -z "$name" ] && name="$fname"
        eval "STRAT_FILE_$STRAT_COUNT=\"$f\""
        eval "STRAT_NAME_$STRAT_COUNT=\"$name\""
        printf "  ${C_BOLD}%2d.${C_RESET} %-42s  [%s]\n" "$STRAT_COUNT" "$name" "$fname"
    done
}

get_strat_file() {
    eval "echo \"\$STRAT_FILE_$1\""
}

get_strat_name() {
    eval "echo \"\$STRAT_NAME_$1\""
}

# --- Copy helper files ---
copy_lists() {
    local src="$SCRIPT_DIR/lists"
    local dst="$ZAPRET_BASE/ipset"
    local copied=0
    for f in list-general.txt list-google.txt list-exclude.txt ipset-exclude.txt; do
        if [ -f "$src/$f" ]; then
            if [ ! -f "$dst/$f" ]; then
                cp "$src/$f" "$dst/$f"
                print_ok "Copied $f -> $dst/"
                copied=$((copied + 1))
            fi
        else
            print_warn "Source $f not found in $src/"
        fi
    done
    if [ "$copied" -eq 0 ]; then
        print_info "All list files already present"
    fi
}

copy_bins() {
    local src="$SCRIPT_DIR/files/fake"
    local dst="$ZAPRET_BASE/files/fake"
    local copied=0
    for f in tls_clienthello_4pda_to.bin tls_clienthello_max_ru.bin; do
        if [ -f "$src/$f" ]; then
            if [ ! -f "$dst/$f" ]; then
                cp "$src/$f" "$dst/$f"
                print_ok "Copied $f -> $dst/"
                copied=$((copied + 1))
            fi
        else
            print_warn "Source $f not found in $src/"
        fi
    done
    if [ "$copied" -eq 0 ]; then
        print_info "All .bin files already present"
    fi
}

# ============================================================
#  MENU ACTIONS
# ============================================================

action_install_strategy() {
    clear
    printf "\n  ${C_BOLD}INSTALL STRATEGY${C_RESET}\n\n"

    if [ -z "$ZAPRET_BASE" ]; then
        print_fail "ZAPRET_BASE not detected. Is zapret installed?"
        pause_prompt; return
    fi
    if [ -z "$CUSTOM_D" ]; then
        print_fail "custom.d directory not found in $ZAPRET_BASE"
        pause_prompt; return
    fi

    if [ ! -d "$SCRIPT_DIR/strategies" ]; then
        print_fail "strategies/ directory not found next to this script"
        pause_prompt; return
    fi

    get_active_strategy
    printf "  Current active strategy: ${C_CYAN}%s${C_RESET}\n\n" "$ACTIVE_STRATEGY"

    list_strategies
    printf "\n  ${C_BOLD} 0.${C_RESET} Cancel\n"

    printf "\n  Select strategy (0-%d): " "$STRAT_COUNT"
    read choice </dev/tty

    case "$choice" in
        ''|0) return ;;
    esac

    # Validate number
    if ! [ "$choice" -ge 1 ] 2>/dev/null || ! [ "$choice" -le "$STRAT_COUNT" ] 2>/dev/null; then
        print_fail "Invalid choice"
        pause_prompt; return
    fi

    sel_file=$(get_strat_file "$choice")
    sel_name=$(get_strat_name "$choice")

    if [ -z "$sel_file" ] || [ ! -f "$sel_file" ]; then
        print_fail "Invalid choice"
        pause_prompt; return
    fi

    printf "\n"
    print_info "Installing strategy: $sel_name"

    # Copy lists and bins first
    copy_lists
    copy_bins

    # Remove old strategy scripts
    for f in "$CUSTOM_D"/50-discord-youtube*; do
        [ -f "$f" ] && rm -f "$f"
    done

    # Install new strategy
    cp "$sel_file" "$CUSTOM_D/"
    print_ok "Installed $(basename "$sel_file") -> $CUSTOM_D/"

    printf "\n  Restart zapret now? (y/N): "
    read yn </dev/tty
    case "$yn" in
        y|Y)
            print_info "Restarting zapret..."
            zapret_cmd restart
            print_ok "Done"
            ;;
    esac

    pause_prompt
}

action_show_active() {
    clear
    printf "\n  ${C_BOLD}ACTIVE STRATEGY${C_RESET}\n\n"

    get_active_strategy

    if [ "$ACTIVE_STRATEGY" = "none" ]; then
        print_warn "No discord-youtube strategy installed"
        if [ -n "$CUSTOM_D" ]; then
            print_info "custom.d dir: $CUSTOM_D"
        fi
    else
        print_ok "Strategy: $ACTIVE_STRATEGY"
        print_info "File: $ACTIVE_FILE"
        printf "\n  ${C_BOLD}nfqws options:${C_RESET}\n"
        # Show the NFQWS_DSCYT_OPT block
        sed -n '/^NFQWS_DSCYT_OPT=/,/}"/p' "$ACTIVE_FILE" | sed 's/^/    /'
    fi

    pause_prompt
}

action_start() {
    clear
    print_info "Starting zapret..."
    zapret_cmd start
    pause_prompt
}

action_stop() {
    clear
    print_info "Stopping zapret..."
    zapret_cmd stop
    pause_prompt
}

action_restart() {
    clear
    print_info "Restarting zapret..."
    zapret_cmd restart
    pause_prompt
}

action_status() {
    clear
    printf "\n  ${C_BOLD}ZAPRET STATUS${C_RESET}\n\n"

    # Check if nfqws is running (ps w shows full command on busybox)
    local nfq_count=$(ps | grep -c '[n]fqws')
    if [ "$nfq_count" -gt 0 ] 2>/dev/null; then
        print_ok "nfqws is RUNNING ($nfq_count instance(s))"
    else
        print_fail "nfqws is NOT running"
    fi

    # Active strategy
    get_active_strategy
    if [ "$ACTIVE_STRATEGY" = "none" ]; then
        print_warn "No discord-youtube strategy installed"
    else
        print_ok "Active strategy: $ACTIVE_STRATEGY"
    fi

    # Init type
    if [ -n "$INIT_TYPE" ]; then
        print_info "Init system: $INIT_TYPE"
    fi

    # Service status via init system
    printf "\n"
    case "$INIT_TYPE" in
        initd|sysv)
            "$INIT_SCRIPT" status 2>/dev/null || true
            ;;
        systemd)
            systemctl status zapret --no-pager -l 2>/dev/null | head -10
            ;;
    esac

    pause_prompt
}

action_edit_lists() {
    clear
    printf "\n  ${C_BOLD}EDIT DOMAIN LISTS${C_RESET}\n\n"

    if [ -z "$ZAPRET_BASE" ]; then
        print_fail "ZAPRET_BASE not detected"
        pause_prompt; return
    fi

    local ipset_dir="$ZAPRET_BASE/ipset"
    local editor=""
    if [ -n "$EDITOR" ]; then
        editor="$EDITOR"
    elif command -v nano >/dev/null 2>&1; then
        editor="nano"
    elif command -v vi >/dev/null 2>&1; then
        editor="vi"
    else
        print_fail "No text editor found (nano or vi)"
        pause_prompt; return
    fi

    printf "  1. list-general.txt    (Discord, Cloudflare - %d domains)\n" \
        "$(wc -l < "$ipset_dir/list-general.txt" 2>/dev/null || echo 0)"
    printf "  2. list-google.txt     (YouTube, Google     - %d domains)\n" \
        "$(wc -l < "$ipset_dir/list-google.txt" 2>/dev/null || echo 0)"
    printf "  3. list-exclude.txt    (Excluded domains    - %d domains)\n" \
        "$(wc -l < "$ipset_dir/list-exclude.txt" 2>/dev/null || echo 0)"
    printf "  4. ipset-exclude.txt   (Excluded IPs        - %d entries)\n" \
        "$(wc -l < "$ipset_dir/ipset-exclude.txt" 2>/dev/null || echo 0)"
    printf "\n  0. Back\n"
    printf "\n  Select list to edit (0-4): "
    read choice </dev/tty

    local target=""
    case "$choice" in
        1) target="$ipset_dir/list-general.txt" ;;
        2) target="$ipset_dir/list-google.txt" ;;
        3) target="$ipset_dir/list-exclude.txt" ;;
        4) target="$ipset_dir/ipset-exclude.txt" ;;
        *) return ;;
    esac

    if [ ! -f "$target" ]; then
        print_fail "File not found: $target"
        printf "  Copy lists first using option 1 (Install Strategy)\n"
        pause_prompt; return
    fi

    print_info "Editing: $target"
    "$editor" "$target" </dev/tty >/dev/tty
    printf "\n  File now has %d lines:\n" "$(wc -l < "$target")"
    head -5 "$target" | sed 's/^/    /'
    [ "$(wc -l < "$target")" -gt 5 ] && printf "    ...\n"
    printf "\n"
    print_info "Restart zapret to apply list changes"
    pause_prompt
}

action_diagnostics() {
    clear
    printf "\n  ${C_BOLD}DIAGNOSTICS${C_RESET}\n\n"

    # 1. ZAPRET_BASE
    if [ -n "$ZAPRET_BASE" ]; then
        print_ok "ZAPRET_BASE: $ZAPRET_BASE"
    else
        print_fail "ZAPRET_BASE not detected"
        pause_prompt; return
    fi

    # 2. nfqws binary
    local nfqws_bin="$ZAPRET_BASE/nfq/nfqws"
    if [ -x "$nfqws_bin" ]; then
        print_ok "nfqws binary found: $nfqws_bin"
    else
        nfqws_bin=$(command -v nfqws 2>/dev/null)
        if [ -n "$nfqws_bin" ]; then
            print_ok "nfqws found in PATH: $nfqws_bin"
        else
            print_fail "nfqws binary not found"
        fi
    fi

    # 3. custom.d
    if [ -n "$CUSTOM_D" ]; then
        print_ok "custom.d: $CUSTOM_D"
    else
        print_fail "custom.d directory not found"
    fi

    # 4. List files
    printf "\n"
    for f in list-general.txt list-google.txt list-exclude.txt ipset-exclude.txt; do
        if [ -f "$ZAPRET_BASE/ipset/$f" ]; then
            local count=$(wc -l < "$ZAPRET_BASE/ipset/$f" 2>/dev/null)
            print_ok "$f ($count entries)"
        else
            print_fail "$f missing from $ZAPRET_BASE/ipset/"
        fi
    done

    # 5. Fake .bin files
    printf "\n"
    for f in quic_initial_www_google_com.bin tls_clienthello_www_google_com.bin stun.bin tls_clienthello_4pda_to.bin tls_clienthello_max_ru.bin; do
        if [ -f "$ZAPRET_BASE/files/fake/$f" ]; then
            print_ok "$f"
        else
            print_fail "$f missing from $ZAPRET_BASE/files/fake/"
        fi
    done

    # 6. nfqws process
    printf "\n"
    local nfq_count=$(ps | grep -c '[n]fqws')
    if [ "$nfq_count" -gt 0 ] 2>/dev/null; then
        print_ok "nfqws process running ($nfq_count instance(s))"
    else
        print_fail "nfqws process not running"
    fi

    # 7. Firewall rules
    printf "\n"
    if command -v iptables >/dev/null 2>&1; then
        if iptables -t mangle -L -n 2>/dev/null | grep -q NFQUEUE; then
            print_ok "iptables NFQUEUE rules found"
        else
            print_warn "No iptables NFQUEUE rules found (might use nftables)"
        fi
    fi
    if command -v nft >/dev/null 2>&1; then
        if nft list ruleset 2>/dev/null | grep -q queue; then
            print_ok "nftables queue rules found"
        else
            print_warn "No nftables queue rules found"
        fi
    fi

    # 8. Active strategy
    printf "\n"
    get_active_strategy
    if [ "$ACTIVE_STRATEGY" != "none" ]; then
        print_ok "Active strategy: $ACTIVE_STRATEGY"
    else
        print_warn "No discord-youtube strategy installed in custom.d"
    fi

    # 9. Other custom.d scripts (potential conflicts)
    if [ -n "$CUSTOM_D" ]; then
        local others=""
        for f in "$CUSTOM_D"/*; do
            [ -f "$f" ] || continue
            case "$(basename "$f")" in
                50-discord-youtube*|.keep) continue ;;
                *) others="$others $(basename "$f")" ;;
            esac
        done
        if [ -n "$others" ]; then
            print_warn "Other custom.d scripts found:$others"
        fi
    fi

    pause_prompt
}

# ============================================================
#  FIRST-RUN SETUP
# ============================================================

first_run_check() {
    if [ -z "$ZAPRET_BASE" ]; then
        return 0  # will show warning in menu
    fi

    # Check if any discord-youtube strategy is installed
    get_active_strategy
    if [ "$ACTIVE_STRATEGY" != "none" ]; then
        return 0  # already set up
    fi

    # Check if lists are present
    if [ -f "$ZAPRET_BASE/ipset/list-general.txt" ]; then
        return 0  # lists present, user just hasn't installed strategy
    fi

    # Nothing installed — offer guided setup
    clear
    printf "\n  ${C_BOLD}FIRST-TIME SETUP${C_RESET}\n\n"
    print_info "No discord-youtube strategy detected."
    printf "  Run guided setup? (Y/n): "
    read yn </dev/tty
    case "$yn" in
        n|N) return 0 ;;
    esac

    printf "\n"
    print_info "Step 1/3: Copying domain lists..."
    copy_lists

    printf "\n"
    print_info "Step 2/3: Copying fake-packet binaries..."
    copy_bins

    printf "\n"
    print_info "Step 3/3: Select a strategy to install\n"
    printf "  Tip: start with #1 (general). Switch later if needed.\n\n"
    list_strategies
    printf "\n  Select strategy (1-%d): " "$STRAT_COUNT"
    read choice </dev/tty

    if [ -n "$choice" ] && [ "$choice" -ge 1 ] 2>/dev/null && [ "$choice" -le "$STRAT_COUNT" ] 2>/dev/null; then
        sel_file=$(get_strat_file "$choice")
        if [ -n "$sel_file" ] && [ -f "$sel_file" ]; then
            for f in "$CUSTOM_D"/50-discord-youtube*; do
                [ -f "$f" ] && rm -f "$f"
            done
            cp "$sel_file" "$CUSTOM_D/"
            sel_name=$(get_strat_name "$choice")
            print_ok "Installed: $sel_name"

            printf "\n  Start zapret now? (Y/n): "
            read yn2 </dev/tty
            case "$yn2" in
                n|N) ;;
                *)
                    print_info "Starting zapret..."
                    zapret_cmd start
                    print_ok "Done"
                    ;;
            esac
        fi
    else
        print_warn "Skipped strategy install. Use menu option 1 later."
    fi

    pause_prompt
}

# ============================================================
#  MAIN MENU
# ============================================================

main_menu() {
    detect_zapret_base
    detect_custom_d
    detect_init_system

    first_run_check

    while true; do
        clear
        get_active_strategy

        printf "\n"
        printf "  ${C_BOLD}ZAPRET DISCORD+YOUTUBE MANAGER${C_RESET}\n"
        printf "  ────────────────────────────────\n"
        printf "\n"
        printf "  ${C_CYAN}:: STRATEGY${C_RESET}\n"
        printf "     1. Install Strategy         ${C_CYAN}[%s]${C_RESET}\n" "$ACTIVE_STRATEGY"
        printf "     2. Show Active Strategy\n"
        printf "\n"
        printf "  ${C_CYAN}:: SERVICE${C_RESET}\n"
        printf "     3. Start zapret\n"
        printf "     4. Stop zapret\n"
        printf "     5. Restart zapret\n"
        printf "     6. Check Status\n"
        printf "\n"
        printf "  ${C_CYAN}:: LISTS${C_RESET}\n"
        printf "     7. Edit Domain Lists\n"
        printf "\n"
        printf "  ${C_CYAN}:: TOOLS${C_RESET}\n"
        printf "     8. Run Diagnostics\n"
        printf "\n"
        printf "  ────────────────────────────────\n"
        printf "     0. Exit\n"
        printf "\n"

        if [ -z "$ZAPRET_BASE" ]; then
            print_fail "ZAPRET_BASE not found! Is zapret installed?"
            printf "\n"
        fi

        printf "  Select option (0-8): "
        read menu_choice </dev/tty

        case "$menu_choice" in
            1) action_install_strategy ;;
            2) action_show_active ;;
            3) action_start ;;
            4) action_stop ;;
            5) action_restart ;;
            6) action_status ;;
            7) action_edit_lists ;;
            8) action_diagnostics ;;
            0|q|Q) printf "\n"; exit 0 ;;
        esac
    done
}

# --- Entry point ---
main_menu
