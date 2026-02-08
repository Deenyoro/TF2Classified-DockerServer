#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Optional Addon Installer for TF2 Classified Docker Server
# Called from entrypoint.sh after SourceMod is installed.
#
# Each addon is toggled by an environment variable (default: false).
# When enabled, addons are downloaded once and cached. When disabled,
# addon plugins are moved to the disabled/ directory and conflicting
# stock plugins are restored.
# ---------------------------------------------------------------------------

# Addon installation is non-critical — failures should warn, never prevent
# the game server from starting. Disable set -e (inherited from entrypoint).
set +e
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()  { echo -e "${CYAN}[STEP]${NC}  $1"; }

GAME_DIR="${1:?Usage: install-addons.sh <game_dir>}"

# SourceMod directory layout
SM_DIR="${GAME_DIR}/addons/sourcemod"
SM_PLUGINS="${SM_DIR}/plugins"
SM_DISABLED="${SM_PLUGINS}/disabled"
SM_CONFIGS="${SM_DIR}/configs"
SM_GAMEDATA="${SM_DIR}/gamedata"
SM_TRANSLATIONS="${SM_DIR}/translations"
SM_SCRIPTING="${SM_DIR}/scripting"

# Marker directory — tracks what our installer has done
ADDON_MARKERS="${SM_DIR}/.addon-markers"

# Download cache — persists across container restarts (on the game volume)
ADDON_CACHE="${GAME_DIR}/.addon-cache"

# Bundled addon files (baked into Docker image)
BUNDLED_DIR="/opt/addons-bundled"

# Bail out if SourceMod isn't installed
if [[ ! -d "${SM_DIR}" ]]; then
    log_info "SourceMod not installed — skipping addon setup"
    exit 0
fi

mkdir -p "${SM_DISABLED}" "${ADDON_MARKERS}" "${ADDON_CACHE}"

# Disable SM's built-in gamedata auto-updater. It overwrites patched gamedata
# files (sm-tf2.games.txt, tf2.items.txt) with stock TF2 versions on every boot,
# destroying the TF2 Classified offsets we need. The custom/ directory provides
# override protection for core SM files, but third-party extensions (TF2Items)
# load their gamedata directly, so we must also prevent overwrites.
if [[ -f "${SM_DIR}/configs/core.cfg" ]]; then
    if grep -q '"DisableAutoUpdate".*"no"' "${SM_DIR}/configs/core.cfg" 2>/dev/null; then
        sed -i 's/"DisableAutoUpdate".*"no"/"DisableAutoUpdate"\t\t\t"yes"/' "${SM_DIR}/configs/core.cfg"
        log_info "  Disabled SM gamedata auto-updater (preserves TF2C patches)"
    fi
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Download a file to the cache if it doesn't already exist
cache_download() {
    local url="$1" filename="$2"
    local dest="${ADDON_CACHE}/${filename}"
    if [[ -f "${dest}" ]]; then
        return 0
    fi
    log_info "  Downloading ${filename}..."
    if curl -fsSL "${url}" -o "${dest}.tmp"; then
        mv "${dest}.tmp" "${dest}"
    else
        rm -f "${dest}.tmp"
        log_warn "  Failed to download: ${url}"
        return 1
    fi
}

# Move a stock SourceMod plugin to disabled/ and record that we did it
disable_stock_plugin() {
    local plugin="$1" reason="$2"
    if [[ -f "${SM_PLUGINS}/${plugin}" ]]; then
        mv "${SM_PLUGINS}/${plugin}" "${SM_DISABLED}/${plugin}" 2>/dev/null || true
        touch "${ADDON_MARKERS}/stock_disabled_${plugin}_by_${reason}"
        log_info "  Disabled stock plugin: ${plugin}"
    fi
}

# Restore a stock plugin that WE disabled (ignore manually disabled ones)
restore_stock_plugin() {
    local plugin="$1" reason="$2"
    if [[ -f "${ADDON_MARKERS}/stock_disabled_${plugin}_by_${reason}" ]]; then
        if [[ -f "${SM_DISABLED}/${plugin}" ]] && [[ ! -f "${SM_PLUGINS}/${plugin}" ]]; then
            mv "${SM_DISABLED}/${plugin}" "${SM_PLUGINS}/${plugin}" 2>/dev/null || true
            log_info "  Restored stock plugin: ${plugin}"
        fi
        rm -f "${ADDON_MARKERS}/stock_disabled_${plugin}_by_${reason}"
    fi
}

# Ensure an addon plugin is in plugins/ (not disabled/)
ensure_plugin_active() {
    local plugin="$1"
    if [[ -f "${SM_DISABLED}/${plugin}" ]] && [[ ! -f "${SM_PLUGINS}/${plugin}" ]]; then
        mv "${SM_DISABLED}/${plugin}" "${SM_PLUGINS}/${plugin}" 2>/dev/null || true
    fi
}

# Move an addon plugin to disabled/
ensure_plugin_disabled() {
    local plugin="$1"
    if [[ -f "${SM_PLUGINS}/${plugin}" ]]; then
        mv "${SM_PLUGINS}/${plugin}" "${SM_DISABLED}/${plugin}" 2>/dev/null || true
    fi
}

# ---------------------------------------------------------------------------
# TF2 Classified Gamedata Patching
# ---------------------------------------------------------------------------
# TF2C uses game identifier "tf2classified" but many addons only include "tf"
# gamedata sections. These functions patch gamedata files to add the TF2C
# sections with correct vtable offsets (which differ from stock TF2).
#
# Offsets were calculated from the TF2C server binary (server_srv.so) by
# finding function pointers in class vtables. After a TF2C update that
# changes class layouts, these offsets may need updating. The validate
# function below checks for this.
# ---------------------------------------------------------------------------

# Install TF2 Classified gamedata into SM's custom/ override directory.
# Files in gamedata/custom/ are never overwritten by SM's auto-updater and
# are parsed after the stock files, so they cleanly override offsets/signatures.
# For third-party extensions (TF2Items) that may not load custom/, we also
# patch the main gamedata file directly as a fallback.
install_tf2c_gamedata() {
    local gamedata_file="$1"
    local patch_file="$2"

    [[ -f "${patch_file}" ]] || return 0

    # Install to custom/ directory (survives SM auto-updater)
    local custom_dir="${SM_GAMEDATA}/custom"
    mkdir -p "${custom_dir}"
    local custom_name="tf2c.$(basename "${gamedata_file}")"
    # Wrap patch content in a proper Games{} block for standalone loading
    if ! grep -q '"Games"' "${patch_file}" 2>/dev/null; then
        {
            echo '"Games"'
            echo '{'
            cat "${patch_file}"
            echo '}'
        } > "${custom_dir}/${custom_name}"
    else
        cp "${patch_file}" "${custom_dir}/${custom_name}"
    fi

    # Also patch the main file directly (for extensions that don't use custom/)
    [[ -f "${gamedata_file}" ]] || return 0
    if grep -q '"tf2classified"' "${gamedata_file}" 2>/dev/null; then
        return 0
    fi

    local tmp="${gamedata_file}.tmp.$$"
    head -n -1 "${gamedata_file}" > "${tmp}"
    cat "${patch_file}" >> "${tmp}"
    echo "}" >> "${tmp}"
    mv "${tmp}" "${gamedata_file}" 2>/dev/null || true
    rm -f "${tmp}"
    log_info "  Patched $(basename "${gamedata_file}") with TF2C gamedata"
}

# Legacy alias used throughout this script
patch_tf2c_gamedata() { install_tf2c_gamedata "$@"; }

# Validate that key symbols still exist in the TF2C binary.
# If a TF2C update changes the binary, symbols may move or disappear.
# This check runs on every boot and warns operators if gamedata may be stale.
validate_tf2c_gamedata() {
    local server_bin="${GAME_DIR}/bin/linux64/server_srv.so"
    [[ -f "${server_bin}" ]] || return 0

    # Quick check: verify a few critical symbols still exist in the binary.
    # Uses grep -c on the binary since nm/readelf may not be installed.
    local missing=0
    for sym in \
        "CEconItemSchema17GetItemDefinitionEi" \
        "CAttributeList24SetRuntimeAttributeValueE" \
        "GEconItemSchemav" \
        "CTFPlayer13GiveNamedItemE" \
        "CTFPlayer14GetLoadoutItemEiib"; do
        if ! grep -qac "${sym}" "${server_bin}" 2>/dev/null; then
            log_warn "  TF2C gamedata: symbol ${sym} not found in server binary!"
            ((missing++)) || true
        fi
    done

    if [[ ${missing} -gt 0 ]]; then
        log_warn "  TF2C may have updated — ${missing} expected symbol(s) missing."
        log_warn "  Addons depending on gamedata (tf2attributes, VSH) may not load."
        log_warn "  Gamedata offsets may need recalculating."
    fi
}

# =========================================================================
# TF2 Attributes
# =========================================================================
install_tf2attributes() {
    if [[ -f "${ADDON_MARKERS}/tf2attributes" ]]; then
        ensure_plugin_active "tf2attributes.smx"
        if [[ -f "${SM_PLUGINS}/tf2attributes.smx" ]]; then
            # Re-patch gamedata if needed (survives SM updates)
            patch_tf2c_gamedata "${SM_GAMEDATA}/tf2.attributes.txt" \
                "${BUNDLED_DIR}/gamedata-tf2c/tf2c.tf2attributes.txt"
            log_info "tf2attributes already installed"
            return 0
        fi
        log_info "tf2attributes plugin missing — reinstalling..."
        rm -f "${ADDON_MARKERS}/tf2attributes"
    fi

    log_step "Installing tf2attributes..."

    local base_url="${TF2ATTR_URL}"
    cache_download "${base_url}/tf2attributes.smx" "tf2attributes.smx" || return 1
    cache_download "${base_url}/tf2.attributes.txt" "tf2.attributes.txt" || return 1

    cp "${ADDON_CACHE}/tf2attributes.smx" "${SM_PLUGINS}/tf2attributes.smx"
    cp "${ADDON_CACHE}/tf2.attributes.txt" "${SM_GAMEDATA}/tf2.attributes.txt"

    # Patch gamedata for TF2 Classified compatibility
    patch_tf2c_gamedata "${SM_GAMEDATA}/tf2.attributes.txt" \
        "${BUNDLED_DIR}/gamedata-tf2c/tf2c.tf2attributes.txt"

    # Also grab the include file for developers who want to compile dependent plugins
    cache_download "${base_url}/tf2attributes.inc" "tf2attributes.inc" 2>/dev/null || true
    if [[ -f "${ADDON_CACHE}/tf2attributes.inc" ]]; then
        mkdir -p "${SM_SCRIPTING}/include"
        cp "${ADDON_CACHE}/tf2attributes.inc" "${SM_SCRIPTING}/include/tf2attributes.inc"
    fi

    touch "${ADDON_MARKERS}/tf2attributes"
    log_info "tf2attributes installed"
}

disable_tf2attributes() {
    ensure_plugin_disabled "tf2attributes.smx"

    # If no other addon needs TF2 Tools, clean up autoload
    if [[ "${ADDON_VSH,,}" != "true" ]] && [[ "${ADDON_WAR3SOURCE,,}" != "true" ]] && [[ "${ADDON_MAPCONFIG,,}" != "true" ]]; then
        rm -f "${SM_DIR}/extensions/game.tf2.autoload"
        rm -f "${SM_DIR}/extensions/game.tf2.ext.2.tf2classified.so"
        rm -f "${SM_DIR}/extensions/x64/game.tf2.ext.2.tf2classified.so"
        rm -f "${SM_DIR}/extensions/game.tf2.ext.2.tf2.so"
        rm -f "${SM_DIR}/extensions/x64/game.tf2.ext.2.tf2.so"
    fi
}

# =========================================================================
# MapChooser Extended
# =========================================================================
install_mapchooser_extended() {
    # Disable conflicting stock plugins
    disable_stock_plugin "mapchooser.smx" "mce"
    disable_stock_plugin "nominations.smx" "mce"
    disable_stock_plugin "rockthevote.smx" "mce"

    if [[ -f "${ADDON_MARKERS}/mapchooser_extended" ]]; then
        ensure_plugin_active "mapchooser_extended.smx"
        ensure_plugin_active "nominations_extended.smx"
        ensure_plugin_active "rockthevote_extended.smx"
        ensure_plugin_active "mapchooser_extended_sounds.smx"
        if [[ -f "${SM_PLUGINS}/mapchooser_extended.smx" ]]; then
            log_info "MapChooser Extended already installed"
            return 0
        fi
        log_info "MapChooser Extended plugin missing — reinstalling..."
        rm -f "${ADDON_MARKERS}/mapchooser_extended"
    fi

    log_step "Installing MapChooser Extended..."

    local archive="mce-master.tar.gz"
    cache_download "${MCE_URL}" "${archive}" || return 1

    local tmp
    tmp="$(mktemp -d)"

    if ! tar -xzf "${ADDON_CACHE}/${archive}" -C "${tmp}" --strip-components=1 2>/dev/null; then
        log_warn "  Extraction warnings for MCE — check logs"
    fi

    # MCE stores .smx in scripting/ (non-standard) — move to plugins/
    for smx in mapchooser_extended nominations_extended rockthevote_extended mapchooser_extended_sounds; do
        if [[ -f "${tmp}/addons/sourcemod/scripting/${smx}.smx" ]]; then
            cp "${tmp}/addons/sourcemod/scripting/${smx}.smx" "${SM_PLUGINS}/${smx}.smx"
        fi
    done

    # Copy include file
    if [[ -f "${tmp}/addons/sourcemod/scripting/include/mapchooser_extended.inc" ]]; then
        mkdir -p "${SM_SCRIPTING}/include"
        cp "${tmp}/addons/sourcemod/scripting/include/mapchooser_extended.inc" \
            "${SM_SCRIPTING}/include/mapchooser_extended.inc"
    fi

    # Copy configs (map lists, sound configs)
    if [[ -d "${tmp}/addons/sourcemod/configs/mapchooser_extended" ]]; then
        mkdir -p "${SM_CONFIGS}/mapchooser_extended"
        cp -r "${tmp}/addons/sourcemod/configs/mapchooser_extended/"* \
            "${SM_CONFIGS}/mapchooser_extended/"
    fi

    # Copy translations
    if [[ -d "${tmp}/addons/sourcemod/translations" ]]; then
        cp -r "${tmp}/addons/sourcemod/translations/"* "${SM_TRANSLATIONS}/" 2>/dev/null || true
    fi

    rm -rf "${tmp}"
    touch "${ADDON_MARKERS}/mapchooser_extended"
    log_info "MapChooser Extended installed"
}

disable_mapchooser_extended() {
    ensure_plugin_disabled "mapchooser_extended.smx"
    ensure_plugin_disabled "nominations_extended.smx"
    ensure_plugin_disabled "rockthevote_extended.smx"
    ensure_plugin_disabled "mapchooser_extended_sounds.smx"

    # Restore stock plugins (only ones we disabled)
    restore_stock_plugin "mapchooser.smx" "mce"
    restore_stock_plugin "nominations.smx" "mce"
    restore_stock_plugin "rockthevote.smx" "mce"
}

# =========================================================================
# NativeVotes Updated
# =========================================================================
install_nativevotes() {
    # Disable conflicting stock plugins
    disable_stock_plugin "basevotes.smx" "nativevotes"
    disable_stock_plugin "funvotes.smx" "nativevotes"

    # If MCE is NOT enabled, NativeVotes also replaces stock map voting
    if [[ "${ADDON_MAPCHOOSER_EXTENDED,,}" != "true" ]]; then
        disable_stock_plugin "mapchooser.smx" "nativevotes"
        disable_stock_plugin "nominations.smx" "nativevotes"
        disable_stock_plugin "rockthevote.smx" "nativevotes"
    fi

    if [[ -f "${ADDON_MARKERS}/nativevotes" ]]; then
        ensure_plugin_active "nativevotes.smx"
        ensure_plugin_active "nativevotes_basecommands.smx"
        ensure_plugin_active "nativevotes_basevotes.smx"
        ensure_plugin_active "nativevotes_funvotes.smx"
        ensure_plugin_active "nativevotes_voterp.smx"

        # NativeVotes map voting plugins: only if MCE is NOT handling it
        if [[ "${ADDON_MAPCHOOSER_EXTENDED,,}" != "true" ]]; then
            ensure_plugin_active "nativevotes_mapchooser.smx"
            ensure_plugin_active "nativevotes_nominations.smx"
            ensure_plugin_active "nativevotes_rockthevote.smx"
        else
            ensure_plugin_disabled "nativevotes_mapchooser.smx"
            ensure_plugin_disabled "nativevotes_nominations.smx"
            ensure_plugin_disabled "nativevotes_rockthevote.smx"
        fi

        if [[ -f "${SM_PLUGINS}/nativevotes.smx" ]]; then
            # Always overlay bundled fix (patches zero-player array crash)
            if [[ -f "${BUNDLED_DIR}/nativevotes/nativevotes.smx" ]]; then
                cp "${BUNDLED_DIR}/nativevotes/nativevotes.smx" "${SM_PLUGINS}/nativevotes.smx" 2>/dev/null || true
            fi
            log_info "NativeVotes already installed"
            return 0
        fi
        log_info "NativeVotes plugin missing — reinstalling..."
        rm -f "${ADDON_MARKERS}/nativevotes"
    fi

    log_step "Installing NativeVotes Updated..."

    local archive="nativevotes.zip"
    cache_download "${NATIVEVOTES_URL}" "${archive}" || return 1

    local tmp
    tmp="$(mktemp -d)"

    if ! unzip -qo "${ADDON_CACHE}/${archive}" -d "${tmp}" 2>/dev/null; then
        log_warn "  Extraction warnings for NativeVotes — check logs"
    fi

    # Install all plugins
    if [[ -d "${tmp}/addons/sourcemod/plugins" ]]; then
        for smx in "${tmp}"/addons/sourcemod/plugins/*.smx; do
            [[ -f "$smx" ]] || continue
            local fname
            fname="$(basename "$smx")"
            cp "$smx" "${SM_PLUGINS}/${fname}"
        done
    fi

    # Overlay bundled fix (patches zero-player array crash in NativeVotes_Display)
    if [[ -f "${BUNDLED_DIR}/nativevotes/nativevotes.smx" ]]; then
        cp "${BUNDLED_DIR}/nativevotes/nativevotes.smx" "${SM_PLUGINS}/nativevotes.smx" 2>/dev/null || true
        log_info "  Applied bundled NativeVotes fix"
    fi

    # If MCE is also enabled, disable NativeVotes' map voting plugins
    # (MCE has built-in NativeVotes integration)
    if [[ "${ADDON_MAPCHOOSER_EXTENDED,,}" == "true" ]]; then
        ensure_plugin_disabled "nativevotes_mapchooser.smx"
        ensure_plugin_disabled "nativevotes_nominations.smx"
        ensure_plugin_disabled "nativevotes_rockthevote.smx"
    fi

    # Install include files (for developers)
    if [[ -d "${tmp}/addons/sourcemod/scripting/include" ]]; then
        mkdir -p "${SM_SCRIPTING}/include"
        cp -r "${tmp}/addons/sourcemod/scripting/include/"* \
            "${SM_SCRIPTING}/include/" 2>/dev/null || true
    fi

    # Install translations
    if [[ -d "${tmp}/addons/sourcemod/translations" ]]; then
        cp -r "${tmp}/addons/sourcemod/translations/"* "${SM_TRANSLATIONS}/" 2>/dev/null || true
    fi

    rm -rf "${tmp}"
    touch "${ADDON_MARKERS}/nativevotes"
    log_info "NativeVotes installed"
}

disable_nativevotes() {
    ensure_plugin_disabled "nativevotes.smx"
    ensure_plugin_disabled "nativevotes_basecommands.smx"
    ensure_plugin_disabled "nativevotes_basevotes.smx"
    ensure_plugin_disabled "nativevotes_funvotes.smx"
    ensure_plugin_disabled "nativevotes_mapchooser.smx"
    ensure_plugin_disabled "nativevotes_nominations.smx"
    ensure_plugin_disabled "nativevotes_rockthevote.smx"
    ensure_plugin_disabled "nativevotes_voterp.smx"

    # Restore stock plugins we disabled
    restore_stock_plugin "basevotes.smx" "nativevotes"
    restore_stock_plugin "funvotes.smx" "nativevotes"
    restore_stock_plugin "mapchooser.smx" "nativevotes"
    restore_stock_plugin "nominations.smx" "nativevotes"
    restore_stock_plugin "rockthevote.smx" "nativevotes"
}

# =========================================================================
# Advertisements
# =========================================================================
install_advertisements() {
    if [[ -f "${ADDON_MARKERS}/advertisements" ]]; then
        ensure_plugin_active "advertisements.smx"
        if [[ -f "${SM_PLUGINS}/advertisements.smx" ]]; then
            log_info "Advertisements already installed"
            return 0
        fi
        log_info "Advertisements plugin missing — reinstalling..."
        rm -f "${ADDON_MARKERS}/advertisements"
    fi

    log_step "Installing Advertisements..."

    local archive="advertisements.zip"
    cache_download "${ADVERTISEMENTS_URL}" "${archive}" || return 1

    local tmp
    tmp="$(mktemp -d)"

    if ! unzip -qo "${ADDON_CACHE}/${archive}" -d "${tmp}" 2>/dev/null; then
        log_warn "  Extraction warnings for Advertisements — check logs"
    fi

    # Install plugin
    if [[ -f "${tmp}/addons/sourcemod/plugins/advertisements.smx" ]]; then
        cp "${tmp}/addons/sourcemod/plugins/advertisements.smx" \
            "${SM_PLUGINS}/advertisements.smx"
    fi

    # Install default config (only if user hasn't provided their own)
    if [[ ! -f "${SM_CONFIGS}/advertisements.txt" ]]; then
        if [[ -f "${tmp}/addons/sourcemod/configs/advertisements.txt" ]]; then
            cp "${tmp}/addons/sourcemod/configs/advertisements.txt" \
                "${SM_CONFIGS}/advertisements.txt"
        elif [[ -f "${BUNDLED_DIR}/advertisements/advertisements.txt" ]]; then
            cp "${BUNDLED_DIR}/advertisements/advertisements.txt" \
                "${SM_CONFIGS}/advertisements.txt"
        fi
    fi

    rm -rf "${tmp}"
    touch "${ADDON_MARKERS}/advertisements"
    log_info "Advertisements installed"
}

disable_advertisements() {
    ensure_plugin_disabled "advertisements.smx"
}

# =========================================================================
# Roll The Dice (RTD)
# =========================================================================
install_rtd() {
    if [[ -f "${ADDON_MARKERS}/rtd" ]]; then
        ensure_plugin_active "rtd.smx"
        if [[ -f "${SM_PLUGINS}/rtd.smx" ]]; then
            log_info "Roll The Dice already installed"
            return 0
        fi
        log_info "RTD plugin missing — reinstalling..."
        rm -f "${ADDON_MARKERS}/rtd"
    fi

    log_step "Installing Roll The Dice (RTD)..."

    # Download official RTD release for configs, translations, and include files
    local archive="rtd.zip"
    cache_download "${RTD_URL}" "${archive}" || return 1

    local tmp
    tmp="$(mktemp -d)"

    if ! unzip -qo "${ADDON_CACHE}/${archive}" -d "${tmp}" 2>/dev/null; then
        log_warn "  Extraction warnings for RTD — check logs"
    fi

    # RTD zip has a flat structure: configs/, plugins/, scripting/ at root
    # (not nested under addons/sourcemod/)

    # Install configs (perk definitions)
    if [[ -d "${tmp}/configs" ]]; then
        cp -r "${tmp}/configs/"* "${SM_CONFIGS}/" 2>/dev/null || true
    elif [[ -d "${tmp}/addons/sourcemod/configs" ]]; then
        cp -r "${tmp}/addons/sourcemod/configs/"* "${SM_CONFIGS}/" 2>/dev/null || true
    fi

    # Install translations
    if [[ -d "${tmp}/translations" ]]; then
        cp -r "${tmp}/translations/"* "${SM_TRANSLATIONS}/" 2>/dev/null || true
    elif [[ -d "${tmp}/addons/sourcemod/translations" ]]; then
        cp -r "${tmp}/addons/sourcemod/translations/"* "${SM_TRANSLATIONS}/" 2>/dev/null || true
    fi

    # Install include file (for developers)
    local inc_dir="${tmp}/scripting/include"
    [[ -d "${inc_dir}" ]] || inc_dir="${tmp}/addons/sourcemod/scripting/include"
    if [[ -d "${inc_dir}" ]]; then
        mkdir -p "${SM_SCRIPTING}/include"
        cp -r "${inc_dir}/"* "${SM_SCRIPTING}/include/" 2>/dev/null || true
    fi

    # Use the BUNDLED rtd.smx (TF2 Classified compatible build)
    # This is a custom build that has been modified to work with TF2C.
    # It overrides the official .smx from the RTD release.
    if [[ -f "${BUNDLED_DIR}/rtd/rtd.smx" ]]; then
        cp "${BUNDLED_DIR}/rtd/rtd.smx" "${SM_PLUGINS}/rtd.smx"
        log_info "  Using bundled TF2C-compatible RTD build"
    elif [[ -f "${tmp}/plugins/rtd.smx" ]]; then
        cp "${tmp}/plugins/rtd.smx" "${SM_PLUGINS}/rtd.smx"
        log_warn "  Bundled RTD not found — using official build (may not work on TF2C)"
    elif [[ -f "${tmp}/addons/sourcemod/plugins/rtd.smx" ]]; then
        cp "${tmp}/addons/sourcemod/plugins/rtd.smx" "${SM_PLUGINS}/rtd.smx"
        log_warn "  Bundled RTD not found — using official build (may not work on TF2C)"
    fi

    rm -rf "${tmp}"
    touch "${ADDON_MARKERS}/rtd"
    log_info "Roll The Dice installed"
}

disable_rtd() {
    ensure_plugin_disabled "rtd.smx"
}

# =========================================================================
# TF2Items Extension (shared dependency — installed automatically by VSH)
# =========================================================================
install_tf2items() {
    if [[ -f "${ADDON_MARKERS}/tf2items" ]]; then
        # Verify extension binary exists
        if ls "${SM_DIR}/extensions/x64/"*tf2items* &>/dev/null; then
            # Re-patch gamedata if needed (survives SM updates)
            patch_tf2c_gamedata "${SM_GAMEDATA}/tf2.items.txt" \
                "${BUNDLED_DIR}/gamedata-tf2c/tf2c.tf2items.txt"
            patch_tf2c_gamedata "${SM_GAMEDATA}/tf2.items.nosoop.txt" \
                "${BUNDLED_DIR}/gamedata-tf2c/tf2c.tf2items.nosoop.txt"
            # Ensure autoload exists (may have been cleaned up by disable)
            touch "${SM_DIR}/extensions/tf2items.autoload"
            return 0
        fi
        log_info "TF2Items extension missing — reinstalling..."
        rm -f "${ADDON_MARKERS}/tf2items"
    fi

    log_info "  Installing TF2Items extension..."

    local archive="tf2items.tar.gz"
    cache_download "${TF2ITEMS_URL}" "${archive}" || return 1

    local tmp
    tmp="$(mktemp -d)"

    if ! tar -xzf "${ADDON_CACHE}/${archive}" -C "${tmp}" 2>/dev/null; then
        log_warn "  Extraction warnings for TF2Items"
    fi

    # Install extension binaries (.so / .dll)
    # TF2Items ships with an x64/ subdirectory. SM 1.13 on 64-bit loads
    # extensions exclusively from extensions/x64/. We must ADD TF2Items'
    # x64 extension to SM's existing x64/ directory (which has 27+ core
    # extensions), NOT replace it or create a parallel copy.
    if [[ -d "${tmp}/addons/sourcemod/extensions" ]]; then
        # Add 64-bit extension to SM's existing x64/ directory
        if [[ -d "${tmp}/addons/sourcemod/extensions/x64" ]]; then
            mkdir -p "${SM_DIR}/extensions/x64"
            cp "${tmp}/addons/sourcemod/extensions/x64/"*.so "${SM_DIR}/extensions/x64/" 2>/dev/null || true
        fi
        # Copy non-directory files (autoload, txt configs) to extensions root
        find "${tmp}/addons/sourcemod/extensions" -maxdepth 1 -type f \
            -exec cp {} "${SM_DIR}/extensions/" \; 2>/dev/null || true
    fi

    # Install gamedata
    if [[ -d "${tmp}/addons/sourcemod/gamedata" ]]; then
        cp -r "${tmp}/addons/sourcemod/gamedata/"* "${SM_GAMEDATA}/" 2>/dev/null || true
    fi

    # Install optional plugin (tf2items_manager)
    if [[ -d "${tmp}/addons/sourcemod/plugins" ]]; then
        cp -r "${tmp}/addons/sourcemod/plugins/"* "${SM_PLUGINS}/" 2>/dev/null || true
    fi

    # Install include
    if [[ -d "${tmp}/addons/sourcemod/scripting/include" ]]; then
        mkdir -p "${SM_SCRIPTING}/include"
        cp -r "${tmp}/addons/sourcemod/scripting/include/"* \
            "${SM_SCRIPTING}/include/" 2>/dev/null || true
    fi

    # Install config
    if [[ -d "${tmp}/addons/sourcemod/configs" ]]; then
        cp -r "${tmp}/addons/sourcemod/configs/"* "${SM_CONFIGS}/" 2>/dev/null || true
    fi

    rm -rf "${tmp}"

    # Patch TF2Items gamedata for TF2 Classified compatibility
    patch_tf2c_gamedata "${SM_GAMEDATA}/tf2.items.txt" \
        "${BUNDLED_DIR}/gamedata-tf2c/tf2c.tf2items.txt"
    patch_tf2c_gamedata "${SM_GAMEDATA}/tf2.items.nosoop.txt" \
        "${BUNDLED_DIR}/gamedata-tf2c/tf2c.tf2items.nosoop.txt"

    touch "${ADDON_MARKERS}/tf2items"
    log_info "  TF2Items extension installed"
}

# Ensure the TF2 Tools game extension loads on TF2 Classified.
# SM auto-loads extensions matching ".2.<gamedir>.so". Since TF2C uses
# game dir "tf2classified" (not "tf"), game.tf2.ext.2.tf2.so won't load.
# The stock extension also hard-codes a strcmp(gamedir, "tf") check.
# We ship a patched binary with that check bypassed (JE→JMP at the
# game folder comparison) so it loads on TF2C.
link_tf2_game_extension() {
    local ext_dir="${SM_DIR}/extensions"
    local patched="${BUNDLED_DIR}/tf2tools-patched/game.tf2.ext.2.tf2classified.so"

    [[ -f "${patched}" ]] || {
        log_warn "  Patched TF2 Tools extension not found — VSH will not work"
        return 1
    }

    local patched_md5
    patched_md5="$(md5sum "${patched}" 2>/dev/null | cut -d' ' -f1)"

    # Re-verify and install patched extension on every boot.
    # SM updates or file corruption could overwrite/damage the patched binary.
    if [[ -d "${ext_dir}/x64" ]]; then
        local dst="${ext_dir}/x64/game.tf2.ext.2.tf2classified.so"
        local dst_md5=""
        [[ -f "${dst}" ]] && dst_md5="$(md5sum "${dst}" 2>/dev/null | cut -d' ' -f1)"
        if [[ "${dst_md5}" != "${patched_md5}" ]]; then
            cp "${patched}" "${dst}"
            chmod 755 "${dst}"
            log_info "  Installed patched TF2 Tools game extension for TF2C"
        fi
        # Replace stock TF2 extension with our patched binary. SM's autoload
        # resolves "game.tf2.ext" → game.tf2.ext.2.tf2.so first. The stock
        # version fails the gamedir check on TF2C, so we overwrite it with
        # the patched binary that has the check bypassed.
        cp -f "${patched}" "${ext_dir}/x64/game.tf2.ext.2.tf2.so"
        chmod 755 "${ext_dir}/x64/game.tf2.ext.2.tf2.so"
    fi

    local dst="${ext_dir}/game.tf2.ext.2.tf2classified.so"
    local dst_md5=""
    [[ -f "${dst}" ]] && dst_md5="$(md5sum "${dst}" 2>/dev/null | cut -d' ' -f1)"
    if [[ "${dst_md5}" != "${patched_md5}" ]]; then
        cp "${patched}" "${dst}"
        chmod 755 "${dst}"
    fi
    cp -f "${patched}" "${ext_dir}/game.tf2.ext.2.tf2.so"
    chmod 755 "${ext_dir}/game.tf2.ext.2.tf2.so"

    # Ensure autoload marker exists on every boot (may be removed by disable)
    touch "${ext_dir}/game.tf2.autoload"
}

# Install TF2 Tools extension gamedata for TF2 Classified compatibility.
# Patches sm-tf2.games.txt directly on every boot to add "tf2classified" sections.
# NOTE: SM's auto-updater may overwrite this file, but the patch is re-applied
# on every container restart. The auto-updater runs after map load, so the
# extension initializes with the patched file. On subsequent boots the patch
# is re-applied before the server starts.
patch_tf2tools_gamedata() {
    local gamedata_file="${SM_GAMEDATA}/sm-tf2.games.txt"
    local patch_file="${BUNDLED_DIR}/gamedata-tf2c/tf2c.sm-tf2.txt"

    [[ -f "${gamedata_file}" ]] || return 0
    [[ -f "${patch_file}" ]] || return 0

    # Re-patch if SM auto-updater overwrote the file (skip if already patched)
    if grep -q '"tf2classified"' "${gamedata_file}" 2>/dev/null; then
        return 0
    fi

    local tmp="${gamedata_file}.tmp.$$"
    head -n -1 "${gamedata_file}" > "${tmp}"
    cat "${patch_file}" >> "${tmp}"
    echo "}" >> "${tmp}"
    mv "${tmp}" "${gamedata_file}" 2>/dev/null || true
    rm -f "${tmp}"
    log_info "  Patched sm-tf2.games.txt with TF2C gamedata"
}

# =========================================================================
# Versus Saxton Hale (VSH)
# =========================================================================
install_vsh() {
    # TF2Items is incompatible with TF2C 64-bit (native segfault in
    # GiveNamedItem detour). VSH has been patched to work without it,
    # using CreateEntityByName + tf2attributes instead.
    # Disable TF2Items if it was previously installed.
    rm -f "${SM_DIR}/extensions/tf2items.autoload"
    rm -f "${SM_DIR}/extensions/tf2items.ext.2.ep2v.so"
    rm -f "${SM_DIR}/extensions/x64/tf2items.ext.2.ep2v.so"

    # TF2 Tools extension needs TF2C gamedata to load
    patch_tf2tools_gamedata

    if [[ -f "${ADDON_MARKERS}/vsh" ]]; then
        ensure_plugin_active "saxtonhale.smx"
        if [[ -f "${SM_PLUGINS}/saxtonhale.smx" ]]; then
            # Ensure the TF2C-compatible build is deployed (not the stock upstream one)
            if [[ -f "${BUNDLED_DIR}/vsh/saxtonhale.smx" ]]; then
                local bundled_md5 deployed_md5
                bundled_md5="$(md5sum "${BUNDLED_DIR}/vsh/saxtonhale.smx" 2>/dev/null | cut -d' ' -f1)"
                deployed_md5="$(md5sum "${SM_PLUGINS}/saxtonhale.smx" 2>/dev/null | cut -d' ' -f1)"
                if [[ "${bundled_md5}" != "${deployed_md5}" ]]; then
                    cp "${BUNDLED_DIR}/vsh/saxtonhale.smx" "${SM_PLUGINS}/saxtonhale.smx"
                    log_info "  Updated VSH to bundled TF2C-compatible build"
                fi
            fi
            log_info "VSH already installed"
            return 0
        fi
        log_info "VSH plugin missing — reinstalling..."
        rm -f "${ADDON_MARKERS}/vsh"
    fi

    log_step "Installing Versus Saxton Hale..."

    local archive="vsh-master.tar.gz"
    cache_download "${VSH_URL}" "${archive}" || return 1

    local tmp
    tmp="$(mktemp -d)"

    if ! tar -xzf "${ADDON_CACHE}/${archive}" -C "${tmp}" --strip-components=1 2>/dev/null; then
        log_warn "  Extraction warnings for VSH"
    fi

    # Install plugin — prefer bundled TF2C-compatible build over upstream
    if [[ -f "${BUNDLED_DIR}/vsh/saxtonhale.smx" ]]; then
        cp "${BUNDLED_DIR}/vsh/saxtonhale.smx" "${SM_PLUGINS}/saxtonhale.smx"
        log_info "  Using bundled TF2C-compatible VSH build"
    elif [[ -f "${tmp}/addons/sourcemod/plugins/saxtonhale.smx" ]]; then
        cp "${tmp}/addons/sourcemod/plugins/saxtonhale.smx" "${SM_PLUGINS}/saxtonhale.smx"
        log_warn "  Bundled VSH not found — using upstream build (may not work on TF2C)"
    fi

    # Install configs
    if [[ -d "${tmp}/addons/sourcemod/configs/saxton_hale" ]]; then
        mkdir -p "${SM_CONFIGS}/saxton_hale"
        cp -r "${tmp}/addons/sourcemod/configs/saxton_hale/"* \
            "${SM_CONFIGS}/saxton_hale/"
    fi

    # Install translations
    if [[ -d "${tmp}/addons/sourcemod/translations" ]]; then
        cp -r "${tmp}/addons/sourcemod/translations/"* "${SM_TRANSLATIONS}/" 2>/dev/null || true
    fi

    # Install include
    if [[ -f "${tmp}/addons/sourcemod/scripting/include/saxtonhale.inc" ]]; then
        mkdir -p "${SM_SCRIPTING}/include"
        cp "${tmp}/addons/sourcemod/scripting/include/saxtonhale.inc" \
            "${SM_SCRIPTING}/include/"
    fi

    # Install game assets (models, materials, sounds)
    for asset_dir in models materials sound; do
        if [[ -d "${tmp}/${asset_dir}" ]]; then
            mkdir -p "${GAME_DIR}/${asset_dir}"
            cp -r "${tmp}/${asset_dir}/"* "${GAME_DIR}/${asset_dir}/" 2>/dev/null || true
        fi
    done

    # Install FastDL-ready bz2 files if available
    if [[ -d "${tmp}/fastdl" ]]; then
        local fastdl_base="${GAME_DIR}/../../fastdl/tf2classified"
        if [[ -d "$(dirname "${fastdl_base}")" ]]; then
            mkdir -p "${fastdl_base}"
            cp -r "${tmp}/fastdl/"* "${fastdl_base}/" 2>/dev/null || true
            log_info "  VSH FastDL assets installed"
        fi
    fi

    rm -rf "${tmp}"
    touch "${ADDON_MARKERS}/vsh"
    log_info "VSH installed (use vsh_ prefixed maps)"
}

disable_vsh() {
    ensure_plugin_disabled "saxtonhale.smx"

    # If no other addon needs TF2Items/TF2Tools, clean up
    # their autoload files to prevent unnecessary extension loading.
    if [[ "${ADDON_TF2ATTRIBUTES,,}" != "true" ]] && [[ "${ADDON_WAR3SOURCE,,}" != "true" ]] && [[ "${ADDON_MAPCONFIG,,}" != "true" ]]; then
        rm -f "${SM_DIR}/extensions/game.tf2.autoload"
        rm -f "${SM_DIR}/extensions/game.tf2.ext.2.tf2classified.so"
        rm -f "${SM_DIR}/extensions/x64/game.tf2.ext.2.tf2classified.so"
        rm -f "${SM_DIR}/extensions/game.tf2.ext.2.tf2.so"
        rm -f "${SM_DIR}/extensions/x64/game.tf2.ext.2.tf2.so"
        rm -f "${SM_DIR}/extensions/tf2items.autoload"
    fi
}

# =========================================================================
# War3Source (Warcraft 3: Source)
# =========================================================================
install_war3source() {
    if [[ -f "${ADDON_MARKERS}/war3source" ]]; then
        # Re-enable plugins if they were disabled
        if [[ -d "${SM_DISABLED}/war3source" ]]; then
            mkdir -p "${SM_PLUGINS}/war3source"
            for smx in "${SM_DISABLED}/war3source/"*.smx; do
                [[ -f "$smx" ]] || continue
                mv "$smx" "${SM_PLUGINS}/war3source/" 2>/dev/null || true
            done
            rmdir "${SM_DISABLED}/war3source" 2>/dev/null || true
        fi
        # Verify plugins actually exist (compiled cache or disabled dir)
        if [[ -d "${SM_PLUGINS}/war3source" ]] && ls "${SM_PLUGINS}/war3source/"*.smx &>/dev/null; then
            log_info "War3Source already installed"
            return 0
        fi
        log_info "War3Source plugins missing — reinstalling..."
        rm -f "${ADDON_MARKERS}/war3source"
    fi

    log_step "Installing War3Source (Warcraft 3)..."

    local archive="war3source-master.tar.gz"
    cache_download "${WAR3SOURCE_URL}" "${archive}" || return 1

    local tmp
    tmp="$(mktemp -d)"

    if ! tar -xzf "${ADDON_CACHE}/${archive}" -C "${tmp}" --strip-components=1 2>/dev/null; then
        log_warn "  Extraction warnings for War3Source"
    fi

    local scripting="${tmp}/addons/sourcemod/scripting"

    # Check if we have cached compiled plugins from a previous run.
    # Invalidate cache if the source archive is newer (upstream update).
    local compiled_cache="${ADDON_CACHE}/war3source_compiled"
    if [[ -d "${compiled_cache}" ]] && [[ "$(ls -A "${compiled_cache}" 2>/dev/null)" ]]; then
        local archive_ts cache_ts
        archive_ts="$(stat -c %Y "${ADDON_CACHE}/${archive}" 2>/dev/null || echo 0)"
        cache_ts="$(stat -c %Y "${compiled_cache}" 2>/dev/null || echo 0)"
        if [[ "${archive_ts}" -gt "${cache_ts}" ]]; then
            log_info "  War3Source source updated — recompiling..."
            rm -rf "${compiled_cache}"
        fi
    fi
    if [[ -d "${compiled_cache}" ]] && [[ "$(ls -A "${compiled_cache}" 2>/dev/null)" ]]; then
        log_info "  Using cached compiled War3Source plugins"
        mkdir -p "${SM_PLUGINS}/war3source"
        cp "${compiled_cache}/"*.smx "${SM_PLUGINS}/war3source/" 2>/dev/null || true
    else
        # War3Source uses old SourcePawn syntax (SM 1.9 era) that modern SM 1.13
        # compilers reject. We need SM 1.10's compiler + includes which support
        # both old and new syntax and provide the standard include files (core.inc
        # etc.) that War3Source's bundled compiler expects but doesn't ship.
        local sm110_cache="${ADDON_CACHE}/sm110"
        local sm110_url="https://sm.alliedmods.net/smdrop/1.10/sourcemod-1.10.0-git6528-linux.tar.gz"
        local sm110_archive="sm110-compiler.tar.gz"

        if [[ ! -f "${sm110_cache}/spcomp" ]]; then
            log_info "  Downloading SM 1.10 compiler for War3Source compilation..."
            cache_download "${sm110_url}" "${sm110_archive}" || { rm -rf "${tmp}"; return 1; }
            mkdir -p "${sm110_cache}"
            # Extract only the scripting directory (compiler + includes)
            # Strip 3 components: addons/sourcemod/scripting/ → extract to cache root
            tar -xzf "${ADDON_CACHE}/${sm110_archive}" -C "${sm110_cache}" \
                --strip-components=3 \
                "addons/sourcemod/scripting" 2>/dev/null || true
        fi

        local spcomp="${sm110_cache}/spcomp"
        if [[ ! -f "${spcomp}" ]]; then
            log_warn "  SM 1.10 compiler not found — cannot compile War3Source"
            rm -rf "${tmp}"
            return 1
        fi
        chmod +x "${spcomp}"

        log_info "  Compiling War3Source plugins (first time only)..."

        # Set compilation target to TF2
        if [[ -f "${scripting}/game_switcher_TF2.sh" ]]; then
            (cd "${scripting}" && bash game_switcher_TF2.sh 2>/dev/null || true)
        fi

        # Fix MAXPLAYERSCUSTOM for 64-player servers.
        # Upstream hardcodes 34 for TF2 (only supports 32p), but TF2C servers
        # can run up to 64 players. Raise to 66 (64 + 2 HLTV) to match CSS/CSGO.
        find "${scripting}" -name "War3Source_Constants.inc" -exec \
            sed -i 's/^#define MAXPLAYERSCUSTOM 34/#define MAXPLAYERSCUSTOM 66/' {} \; 2>/dev/null || true

        # Fix duplicate SkillName constant (W3SkillProp vs SkillString enum collision)
        # Applies to both directory layouts (War3Source/include/ and W3SIncs/)
        find "${scripting}" -name "War3Source_Constants.inc" -exec \
            sed -i 's/^[[:space:]]*SkillName,$/\tSkillStringName,/' {} \; 2>/dev/null || true

        # Make tf2attributes an optional dependency for TF2C compatibility.
        # TF2C doesn't have the CEconItemSchema economy system, so tf2attributes
        # can never load. Uncomment #undef REQUIRE_PLUGIN so the core engine
        # compiles with tf2attributes as optional (required=0).
        find "${scripting}" -name "War3Source_Engine_BuffMaxHP.sp" -exec \
            sed -i 's|^//#undef REQUIRE_PLUGIN|#undef REQUIRE_PLUGIN|' {} \; 2>/dev/null || true
        # For standalone race plugins that hard-include tf2attributes, add
        # #undef REQUIRE_PLUGIN before their include to make it optional too.
        find "${scripting}" -maxdepth 1 -name "War3Source_*.sp" -exec \
            sed -i 's|^#include <tf2attributes>|#undef REQUIRE_PLUGIN\n#include <tf2attributes>|' {} \; 2>/dev/null || true

        # Replace SteamTools engine with 64-bit compatible stubs.
        # The real steamtools.inc uses deprecated funcenum syntax that won't compile,
        # and the SteamTools extension has no 64-bit build. We replace the engine
        # with stubs that register the War3_IsInSteamGroup native (always returns
        # false) so dependent plugins like W3S-Shopitems still load.
        if [[ -f "${scripting}/War3Source/War3Source_Engine_SteamTools.sp" ]]; then
            cat > "${scripting}/War3Source/War3Source_Engine_SteamTools.sp" << 'STEAMSTUB'
// SteamTools stub for 64-bit SM (no SteamTools extension available)
#if (GGAMETYPE != GGAME_CSGO)
public W3ONLY(){}
public War3Source_Engine_SteamTools_OnPluginStart() {}
public War3Source_Engine_SteamTools_OnClientConnected(client) { bIsInSteamGroup[client] = false; }
public War3Source_Engine_SteamTools_OnClientPutInServer(client) {}
public bool:War3Source_Engine_SteamTools_InitNatives() {
    CreateNative("War3_IsInSteamGroup", NWar3_isingroup_stub);
    return true;
}
public NWar3_isingroup_stub(Handle:plugin, numParams) { return false; }
#endif
STEAMSTUB
        fi

        mkdir -p "${scripting}/compiled"

        # Compile all War3Source .sp files including engine and WCX plugins.
        # SM 1.10 standard includes come FIRST for consistent type definitions,
        # then scripting dir for relative includes, then bundled includes for
        # War3Source-specific headers (war3source.inc, smlib, etc.)
        local compiled=0 failed=0
        for sp in "${scripting}"/War3Source*.sp "${scripting}"/Engine_*.sp "${scripting}"/WCX_Engine_*.sp; do
            [[ -f "$sp" ]] || continue
            local name
            name="$(basename "${sp%.sp}")"
            if "${spcomp}" \
                -i "${sm110_cache}/include" \
                -i "${scripting}" \
                -i "${scripting}/include" \
                "$sp" \
                -o "${scripting}/compiled/${name}.smx" \
                2>/dev/null; then
                ((compiled++)) || true
            else
                ((failed++)) || true
            fi
        done

        log_info "  Compiled ${compiled} plugins (${failed} warnings/failures)"

        # Install compiled plugins
        mkdir -p "${SM_PLUGINS}/war3source"
        for smx in "${scripting}"/compiled/*.smx; do
            [[ -f "$smx" ]] || continue
            cp "$smx" "${SM_PLUGINS}/war3source/"
        done

        # Cache compiled plugins for next boot
        mkdir -p "${compiled_cache}"
        cp "${scripting}"/compiled/*.smx "${compiled_cache}/" 2>/dev/null || true
    fi

    # Install configs
    if [[ -d "${tmp}/addons/sourcemod/configs" ]]; then
        cp -r "${tmp}/addons/sourcemod/configs/"* "${SM_CONFIGS}/" 2>/dev/null || true
    fi

    # Install translations
    if [[ -d "${tmp}/addons/sourcemod/translations" ]]; then
        cp -r "${tmp}/addons/sourcemod/translations/"* "${SM_TRANSLATIONS}/" 2>/dev/null || true
    fi

    # Install gamedata
    if [[ -d "${tmp}/addons/sourcemod/gamedata" ]]; then
        cp -r "${tmp}/addons/sourcemod/gamedata/"* "${SM_GAMEDATA}/" 2>/dev/null || true
    fi

    # Install extensions — skip 32-bit only extensions (steamtools, socket)
    # that have no 64-bit builds and would produce <OPTIONAL> warnings.
    if [[ -d "${tmp}/addons/sourcemod/extensions" ]]; then
        if [[ -d "${tmp}/addons/sourcemod/extensions/x64" ]]; then
            mkdir -p "${SM_DIR}/extensions/x64"
            cp "${tmp}/addons/sourcemod/extensions/x64/"*.so "${SM_DIR}/extensions/x64/" 2>/dev/null || true
        fi
        find "${tmp}/addons/sourcemod/extensions" -maxdepth 1 -type f \
            ! -name "steamtools*" ! -name "socket*" \
            -exec cp {} "${SM_DIR}/extensions/" \; 2>/dev/null || true
    fi

    # Install server configs (cfg/war3source*.cfg)
    if [[ -d "${tmp}/cfg" ]]; then
        cp -r "${tmp}/cfg/"* "${GAME_DIR}/cfg/" 2>/dev/null || true
    fi

    # Install sounds
    if [[ -d "${tmp}/sound" ]]; then
        mkdir -p "${GAME_DIR}/sound"
        cp -r "${tmp}/sound/"* "${GAME_DIR}/sound/" 2>/dev/null || true
    fi

    rm -rf "${tmp}"
    touch "${ADDON_MARKERS}/war3source"
    log_info "War3Source installed"
}

# =========================================================================
# Round-Time (sm_addtime / sm_settime)
# =========================================================================
install_roundtime() {
    if [[ -f "${ADDON_MARKERS}/roundtime" ]]; then
        ensure_plugin_active "Time.smx"
        if [[ -f "${SM_PLUGINS}/Time.smx" ]]; then
            log_info "Round-Time already installed"
            return 0
        fi
        log_info "Round-Time plugin missing — reinstalling..."
        rm -f "${ADDON_MARKERS}/roundtime"
    fi

    log_step "Installing Round-Time..."

    cache_download "${ROUNDTIME_URL}" "Time.smx" || return 1

    cp "${ADDON_CACHE}/Time.smx" "${SM_PLUGINS}/Time.smx"

    touch "${ADDON_MARKERS}/roundtime"
    log_info "Round-Time installed"
}

disable_roundtime() {
    ensure_plugin_disabled "Time.smx"
}

# =========================================================================
# Map Config (YAMCP — per-map/prefix/gametype cfg execution)
# =========================================================================
install_mapconfig() {
    if [[ -f "${ADDON_MARKERS}/mapconfig" ]]; then
        ensure_plugin_active "yamcp.smx"
        if [[ -f "${SM_PLUGINS}/yamcp.smx" ]]; then
            log_info "Map Config already installed"
            return 0
        fi
        log_info "Map Config plugin missing — reinstalling..."
        rm -f "${ADDON_MARKERS}/mapconfig"
    fi

    log_step "Installing Map Config (YAMCP)..."

    if [[ -f "${BUNDLED_DIR}/mapconfig/yamcp.smx" ]]; then
        cp "${BUNDLED_DIR}/mapconfig/yamcp.smx" "${SM_PLUGINS}/yamcp.smx"
    else
        log_warn "  Bundled yamcp.smx not found — cannot install Map Config"
        return 1
    fi

    # Create the mapconfig directory structure for users to populate
    local mapconfig_dir="${GAME_DIR}/cfg/mapconfig"
    mkdir -p "${mapconfig_dir}/gametype" "${mapconfig_dir}/maps"

    # Create a default all.cfg if it doesn't exist
    if [[ ! -f "${mapconfig_dir}/all.cfg" ]]; then
        cat > "${mapconfig_dir}/all.cfg" << 'ALLCFG'
// Map Config — all.cfg
// This file is executed on every map change.
// Add commands that should apply to all maps here.
ALLCFG
    fi

    touch "${ADDON_MARKERS}/mapconfig"
    log_info "Map Config installed (edit cfg/mapconfig/ to configure)"
}

disable_mapconfig() {
    ensure_plugin_disabled "yamcp.smx"

    # If no other addon needs TF2 Tools, clean up
    if [[ "${ADDON_VSH,,}" != "true" ]] && [[ "${ADDON_TF2ATTRIBUTES,,}" != "true" ]] && [[ "${ADDON_WAR3SOURCE,,}" != "true" ]]; then
        rm -f "${SM_DIR}/extensions/game.tf2.autoload"
        rm -f "${SM_DIR}/extensions/game.tf2.ext.2.tf2classified.so"
        rm -f "${SM_DIR}/extensions/x64/game.tf2.ext.2.tf2classified.so"
        rm -f "${SM_DIR}/extensions/game.tf2.ext.2.tf2.so"
        rm -f "${SM_DIR}/extensions/x64/game.tf2.ext.2.tf2.so"
    fi
}

# =========================================================================
# War3Source (Warcraft 3: Source)
# =========================================================================
disable_war3source() {
    # War3Source uses a plugins subdirectory
    if [[ -d "${SM_PLUGINS}/war3source" ]]; then
        mkdir -p "${SM_DISABLED}/war3source"
        for smx in "${SM_PLUGINS}/war3source/"*.smx; do
            [[ -f "$smx" ]] || continue
            mv "$smx" "${SM_DISABLED}/war3source/" 2>/dev/null || true
        done
        rmdir "${SM_PLUGINS}/war3source" 2>/dev/null || true
    fi

    # Remove War3Source configs and sounds from game directory
    # (prevents contamination bleeding into non-War3Source servers)
    rm -f "${GAME_DIR}/cfg/war3source.cfg" \
          "${GAME_DIR}/cfg/war3source_tf2.cfg" \
          "${GAME_DIR}/cfg/war3source_css.cfg" \
          "${GAME_DIR}/cfg/war3source_csgo.cfg" \
          "${GAME_DIR}/cfg/war3source_fof.cfg" 2>/dev/null || true
    rm -rf "${GAME_DIR}/sound/war3source" 2>/dev/null || true

    # If no other addon needs TF2 Tools, clean up autoload
    if [[ "${ADDON_VSH,,}" != "true" ]] && [[ "${ADDON_TF2ATTRIBUTES,,}" != "true" ]] && [[ "${ADDON_MAPCONFIG,,}" != "true" ]]; then
        rm -f "${SM_DIR}/extensions/game.tf2.autoload"
        rm -f "${SM_DIR}/extensions/game.tf2.ext.2.tf2classified.so"
        rm -f "${SM_DIR}/extensions/x64/game.tf2.ext.2.tf2classified.so"
        rm -f "${SM_DIR}/extensions/game.tf2.ext.2.tf2.so"
        rm -f "${SM_DIR}/extensions/x64/game.tf2.ext.2.tf2.so"
    fi
}

# =========================================================================
# Main — Process each addon
# =========================================================================

# Check if ANY addon is enabled
any_enabled=false
for var in ADDON_TF2ATTRIBUTES ADDON_MAPCHOOSER_EXTENDED ADDON_NATIVEVOTES ADDON_ADVERTISEMENTS ADDON_RTD ADDON_VSH ADDON_WAR3SOURCE ADDON_ROUNDTIME ADDON_MAPCONFIG; do
    if [[ "${!var,,}" == "true" ]]; then
        any_enabled=true
        break
    fi
done

if ! ${any_enabled}; then
    # Even if nothing is enabled, we may need to disable previously-enabled addons
    if [[ -d "${ADDON_MARKERS}" ]] && [[ "$(ls -A "${ADDON_MARKERS}" 2>/dev/null)" ]]; then
        log_step "Disabling previously enabled addons..."
        disable_tf2attributes
        disable_mapchooser_extended
        disable_nativevotes
        disable_advertisements
        disable_rtd
        disable_vsh
        disable_war3source
        disable_roundtime
        disable_mapconfig
    fi
    exit 0
fi

log_step "Setting up optional addons..."

# Validate TF2C binary symbols on every boot (warns if TF2C updated and offsets are stale)
validate_tf2c_gamedata

# Patch TF2 Tools gamedata and install patched extension for TF2C compatibility
# Re-applied every boot since SM's auto-updater may overwrite sm-tf2.games.txt
if [[ "${ADDON_VSH,,}" == "true" ]] || [[ "${ADDON_TF2ATTRIBUTES,,}" == "true" ]] || [[ "${ADDON_WAR3SOURCE,,}" == "true" ]] || [[ "${ADDON_MAPCONFIG,,}" == "true" ]]; then
    patch_tf2tools_gamedata
    link_tf2_game_extension
fi

# Patch TF2Items gamedata if the extension was previously installed (has autoload)
# This prevents FAILED extension warnings even when VSH is disabled
if [[ -f "${SM_DIR}/extensions/tf2items.autoload" ]]; then
    patch_tf2c_gamedata "${SM_GAMEDATA}/tf2.items.txt" \
        "${BUNDLED_DIR}/gamedata-tf2c/tf2c.tf2items.txt"
    patch_tf2c_gamedata "${SM_GAMEDATA}/tf2.items.nosoop.txt" \
        "${BUNDLED_DIR}/gamedata-tf2c/tf2c.tf2items.nosoop.txt"
fi

# --- TF2 Attributes ---
# Note: tf2attributes requires CEconItemSchema which doesn't exist in TF2C.
# Only install when explicitly enabled by the user. War3Source compiles with
# tf2attributes as optional so it works without it.
if [[ "${ADDON_TF2ATTRIBUTES,,}" == "true" ]]; then
    install_tf2attributes || log_warn "tf2attributes installation failed — skipping"
else
    disable_tf2attributes
fi

# --- MapChooser Extended ---
# Install MCE BEFORE NativeVotes so NativeVotes knows whether to include
# its own map voting plugins or defer to MCE
if [[ "${ADDON_MAPCHOOSER_EXTENDED,,}" == "true" ]]; then
    install_mapchooser_extended || log_warn "MapChooser Extended installation failed — skipping"
else
    disable_mapchooser_extended
fi

# --- NativeVotes ---
if [[ "${ADDON_NATIVEVOTES,,}" == "true" ]]; then
    install_nativevotes || log_warn "NativeVotes installation failed — skipping"
else
    disable_nativevotes
fi

# --- Advertisements ---
if [[ "${ADDON_ADVERTISEMENTS,,}" == "true" ]]; then
    install_advertisements || log_warn "Advertisements installation failed — skipping"
else
    disable_advertisements
fi

# --- Roll The Dice ---
if [[ "${ADDON_RTD,,}" == "true" ]]; then
    install_rtd || log_warn "RTD installation failed — skipping"
else
    disable_rtd
fi

# --- Versus Saxton Hale ---
if [[ "${ADDON_VSH,,}" == "true" ]]; then
    install_vsh || log_warn "VSH installation failed — skipping"
else
    disable_vsh
fi

# --- War3Source ---
if [[ "${ADDON_WAR3SOURCE,,}" == "true" ]]; then
    install_war3source || log_warn "War3Source installation failed — skipping"
else
    disable_war3source
fi

# --- Round-Time ---
if [[ "${ADDON_ROUNDTIME,,}" == "true" ]]; then
    install_roundtime || log_warn "Round-Time installation failed — skipping"
else
    disable_roundtime
fi

# --- Map Config ---
if [[ "${ADDON_MAPCONFIG,,}" == "true" ]]; then
    install_mapconfig || log_warn "Map Config installation failed — skipping"
else
    disable_mapconfig
fi

# --- Summary ---
echo ""
log_info "Addon status:"
for addon in TF2ATTRIBUTES MAPCHOOSER_EXTENDED NATIVEVOTES ADVERTISEMENTS RTD VSH WAR3SOURCE ROUNDTIME MAPCONFIG; do
    var="ADDON_${addon}"
    if [[ "${!var,,}" == "true" ]]; then
        echo -e "  ${GREEN}ON${NC}   ${addon}"
    fi
done
echo ""
