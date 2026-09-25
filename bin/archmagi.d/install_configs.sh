# Every managed live <-> repo pair, as kind::live::repo. Configs, sync, and
# the redeploy drift check all walk this one list.
#   tree  user dir; sync also walks live to pick up new files
#   root  root-owned dir; only repo-tracked files are managed
#   file  single file
#   exe   single file installed with `install -m 755`
ARCHMAGI_MAP=(
    "root::/etc::etc"
    "root::/usr::usr"
    "file::$HOME/.zshrc::.zshrc"
    "tree::$HOME/.config/hypr::hypr"
    "tree::$HOME/.config/waybar::waybar"
    "tree::$HOME/.config/rofi::rofi"
    "tree::$HOME/.config/nvim::nvim"
    "tree::$HOME/.config/kitty::kitty"
    "tree::$HOME/.config/tmux::tmux"
    "tree::$HOME/.config/btop::btop"
    "tree::$HOME/.config/swaync::swaync"
    "exe::$HOME/.local/bin/archmagi::bin/archmagi"
    "tree::$HOME/.local/bin/archmagi.d::bin/archmagi.d"
    "file::$HOME/wallpapers/nerv-wallpaper.png::wallpapers/nerv-wallpaper.png"
)

# _map_each FN: calls FN KIND LIVE REPO_REL per entry; stops on non-zero.
_map_each() {
    local fn=$1 e kind live rel rc
    for e in "${ARCHMAGI_MAP[@]}"; do
        kind=${e%%::*}; e=${e#*::}; live=${e%%::*}; rel=${e#*::}
        "$fn" "$kind" "$live" "$rel" || { rc=$?; return $rc; }
    done
}

# Repo-relative paths of the tracked files under REL (REL itself for a file).
_map_repo_files() {
    local rel=$1
    if [[ -d "$repo/$rel" ]]; then
        find "$repo/$rel" -type f -printf "$rel/%P\n"
    elif [[ -f "$repo/$rel" ]]; then
        echo "$rel"
    fi
}

# True for a template or a file rendered from one. Those reach the live system
# only through the template phase, never by copy or sync.
_map_templated() {
    [[ "$1" == *.tmpl || -f "$repo/$1.tmpl" ]]
}

_configs_entry() {
    local kind=$1 live=$2 rel=$3 f dst as=""
    case "$kind" in
        file) mkdir -p "${live%/*}" && cp "$repo/$rel" "$live" ;;
        # `install` unlinks first, so a running archmagi keeps executing from
        # its open inode instead of reading a truncated-then-rewritten file.
        exe)  mkdir -p "${live%/*}" && install -m 755 "$repo/$rel" "$live" ;;
        tree|root)
            [[ "$kind" == root ]] && as=sudo
            while IFS= read -r f; do
                _map_templated "$f" && continue
                dst="$live/${f#"$rel/"}"
                $as mkdir -p "${dst%/*}" && $as cp "$repo/$f" "$dst" || return 1
            done < <(_map_repo_files "$rel")
            ;;
    esac
}

_install_configs() {
    local repo=$1
    _map_each _configs_entry || return 1

    sudo chmod +x /usr/local/bin/start-greeter.sh || return 1
    mkdir -p ~/images/screenshots
}

_install_find_repo() {
    if [[ -f "$PWD/etc/hostname.tmpl" ]]; then
        echo "$PWD"
        return 0
    fi
    echo "templates not found; run from the archmagi repo (must contain etc/hostname.tmpl)" >&2
    return 1
}
