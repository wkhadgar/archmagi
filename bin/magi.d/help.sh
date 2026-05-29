# magi help — top-level usage with all command groups.

cmd_help() {
    cat <<EOF
${BOLD}${RED}MAGI SYSTEM${RESET} ${MUTED}// COMMAND INTERFACE${RESET}

  ${AMBER}status${RESET}                       overview (host, tailnet, updates, system)
  ${AMBER}cheatsheet${RESET}                   rofi popup of all Hyprland keybindings
  ${AMBER}tmux${RESET} <${MUTED}sub${RESET}>                   tmux session control:
    ${AMBER}attach${RESET} [${MUTED}session${RESET}]            attach (or create) a session (default MAGI)
    ${AMBER}list${RESET}                       list sessions
    ${AMBER}switch${RESET}                     fzf-pick a session to switch to
    ${AMBER}detach${RESET}                     detach the current client
    ${AMBER}kill${RESET} <${MUTED}session${RESET}>             kill a session (confirms first)
  ${AMBER}update${RESET} [${AMBER}run${RESET}|${AMBER}check${RESET} [${MUTED}-j${RESET}]]    interactive paru -Syu wrapper; ${AMBER}check${RESET} returns pending count
  ${AMBER}tailnet${RESET} <${MUTED}host${RESET}>               tailnet status of a MAGI node
  ${AMBER}confirm${RESET} <${MUTED}msg${RESET}>                rofi confirm dialog (exit 0 = yes)
  ${AMBER}lock${RESET}                         hyprlock
  ${AMBER}reboot${RESET} | ${AMBER}exit${RESET} | ${AMBER}shutdown${RESET}     confirm + hyprshutdown-chained power action
  ${AMBER}restart${RESET} <${AMBER}waybar${RESET}|${AMBER}xdph${RESET}>        kill + relaunch a desktop service
  ${AMBER}install${RESET} ${AMBER}boot${RESET}                  install NERV bootloader theme (detects grub or limine)
  ${AMBER}help${RESET}                         this message
EOF
}
