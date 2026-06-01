# `archmagi install sync`: diff-based pull from live system back into the repo.
# Skips files that bootstrap owns via templates (their .tmpl is the source) and
# gitignored, churn-prone artifacts like lazy.nvim's lock file.

# Skip templated outputs (one-way: repo -> live) and gitignored churn.
# @return 0 if excluded, 1 otherwise.
_install_sync_excluded() {
    case "$1" in
        etc/hostname|etc/hosts|hypr/hyprlock.conf|hypr/hyprland/monit.conf) return 0 ;;
        nvim/lazy-lock.json) return 0 ;;
        *.tmpl) return 0 ;;
    esac
    return 1
}

# Compare one live file to its repo counterpart; prompt to overwrite if they differ.
# @param 1 absolute live path
# @param 2 repo-relative destination path
# @param 3 absolute repo root
# @return 0 normal, 2 if user quit (caller should propagate)
_install_sync_file() {
    local live=$1 repo_rel=$2 abs_repo=$3
    local repo_file="$abs_repo/$repo_rel"
    _install_sync_excluded "$repo_rel" && return 0
    [[ -e "$live" ]] || return 0

    local sudo_cmd=""
    [[ "$live" == /etc/* || "$live" == /usr/* ]] && sudo_cmd=sudo

    if [[ -e "$repo_file" ]] && $sudo_cmd diff -q "$live" "$repo_file" >/dev/null 2>&1; then
        return 0
    fi

    if [[ -e "$repo_file" ]]; then
        printf "\n  ${RED}▌${RESET} ${BOLD}diff${RESET}   %s\n" "$repo_rel"
        $sudo_cmd diff -u "$repo_file" "$live" | head -20
    else
        printf "\n  ${RED}▌${RESET} ${BOLD}new${RESET}    %s\n" "$repo_rel"
    fi
    printf "  ${RED}▌${RESET} pull live -> repo? [y/N/q] "
    local ans; read -r ans
    case "$ans" in
        [yY]*)
            mkdir -p "$(dirname "$repo_file")"
            $sudo_cmd cp "$live" "$repo_file"
            [[ -n "$sudo_cmd" ]] && sudo chown "$USER:$USER" "$repo_file"
            ;;
        [qQ]*) return 2 ;;
    esac
}

# Recursively prompt on every file under live_root vs repo_root.
# @param 1 absolute live tree root
# @param 2 repo-relative tree root
# @param 3 absolute repo root
# @return 0 normal, 2 if user quit
_install_sync_tree() {
    local live_root=$1 repo_rel_root=$2 abs_repo=$3
    [[ -d "$live_root" ]] || return 0
    local f rel
    while IFS= read -r f; do
        rel=${f#"$live_root/"}
        _install_sync_file "$f" "$repo_rel_root/$rel" "$abs_repo"
        (( $? == 2 )) && return 2
    done < <(find "$live_root" -type f 2>/dev/null)
}

# Walk every live -> repo pair, prompting per drifted file.
_install_sync() {
    local repo
    repo=$(_install_find_repo) || return 1

    local files=(
        "/etc/greetd/config.toml::etc/greetd/config.toml"
        "/etc/issue::etc/issue"
        "/etc/pacman.d/hooks/95-limine-esp.hook::etc/pacman.d/hooks/95-limine-esp.hook"
        "/usr/local/bin/start-greeter.sh::usr/local/bin/start-greeter.sh"
        "$HOME/.zshrc::.zshrc"
        "$HOME/.local/bin/archmagi::bin/archmagi"
        "$HOME/wallpapers/nerv-wallpaper.png::wallpapers/nerv-wallpaper.png"
    )
    local trees=(
        "$HOME/.config/hypr::hypr"
        "$HOME/.config/waybar::waybar"
        "$HOME/.config/rofi::rofi"
        "$HOME/.config/nvim::nvim"
        "$HOME/.config/kitty::kitty"
        "$HOME/.config/tmux::tmux"
        "$HOME/.config/btop::btop"
        "$HOME/.config/swaync::swaync"
        "$HOME/.local/bin/archmagi.d::bin/archmagi.d"
    )

    local pair live repo_rel
    for pair in "${files[@]}"; do
        live=${pair%%::*}; repo_rel=${pair##*::}
        _install_sync_file "$live" "$repo_rel" "$repo"
        (( $? == 2 )) && { echo "  ${RED}▌${RESET} sync aborted"; return 0; }
    done
    for pair in "${trees[@]}"; do
        live=${pair%%::*}; repo_rel=${pair##*::}
        _install_sync_tree "$live" "$repo_rel" "$repo"
        (( $? == 2 )) && { echo "  ${RED}▌${RESET} sync aborted"; return 0; }
    done

    echo "  ${RED}▌${RESET} sync done"
}
