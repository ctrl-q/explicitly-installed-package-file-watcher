# explicit-package-file-watcher

Watches files belonging to explicitly installed packages and logs who accesses them.

Monitors files owned by packages listed in `$XDG_DATA_HOME/explicit-package-file-watcher/packages-to-monitor`. Supported package sources: pacman/pikaur, Firefox add-ons, Obsidian plugins, Cura plugins, Vim plugins, eget binaries, npm globals, and yazi plugins.

Each access event is logged with a timestamp, file path, and the process that triggered it.

## Dependencies

`bash`, `coreutils`, `findutils`, `gawk`, `grep`, `inotify-tools`, `pikaur`, `jq`
