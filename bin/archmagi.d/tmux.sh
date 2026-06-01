# archmagi tmux: tmux session control wrapper.

_tmux_attach() {
    local session="${1:-MAGI}"
    if [[ -n "$TMUX" ]]; then
        # Inside tmux: create detached if missing, then switch (never nest).
        tmux has-session -t "$session" 2>/dev/null || tmux new-session -d -s "$session"
        tmux switch-client -t "$session"
    else
        # -A attaches when the session exists, creates it otherwise.
        tmux new-session -A -s "$session"
    fi
}

cmd_tmux() {
    if ! command -v tmux >/dev/null 2>&1; then
        echo "archmagi: tmux is not installed" >&2
        return 1
    fi

    local sub="${1:-attach}"; shift || true
    case "$sub" in
        attach|a)
            _tmux_attach "$@"
            ;;
        list|ls)
            tmux list-sessions 2>/dev/null || echo "no sessions"
            ;;
        switch|sw)
            command -v fzf >/dev/null 2>&1 || { echo "archmagi: fzf is not installed" >&2; return 1; }
            local target
            target=$(tmux list-sessions -F '#{session_name}' 2>/dev/null | fzf --prompt="MAGI session> ") || return 0
            [[ -z "$target" ]] && return 0
            if [[ -n "$TMUX" ]]; then
                tmux switch-client -t "$target"
            else
                tmux attach-session -t "$target"
            fi
            ;;
        detach|d)
            if [[ -z "$TMUX" ]]; then
                echo "archmagi: not inside a tmux session" >&2
                return 1
            fi
            tmux detach-client
            ;;
        kill|k)
            local session="${1:?usage: archmagi tmux kill <session>}"
            tmux has-session -t "$session" 2>/dev/null || { echo "archmagi: no such session: $session" >&2; return 1; }
            printf '%skill session %s? [y/N]%s ' "$AMBER" "$session" "$RESET"
            local ans; read -r ans
            [[ "$ans" == [yY]* ]] || { echo "aborted"; return 1; }
            tmux kill-session -t "$session"
            ;;
        *)
            echo "archmagi: unknown tmux subcommand: $sub" >&2
            return 1
            ;;
    esac
}
