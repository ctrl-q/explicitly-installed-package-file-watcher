#!/bin/bash

readonly bun_package_file="${EXPLICIT_PACKAGE_FILE_WATCHER_BUN_PACKAGE_FILE:-${HOME}/.cache/.bun/install/global/package.json}"
readonly cura_data_dir="${EXPLICIT_PACKAGE_FILE_WATCHER_CURA_DATA_DIR:-${HOME}/.local/share/cura/}"
readonly eget_packages_dir="${EXPLICIT_PACKAGE_FILE_WATCHER_EGET_PACKAGES_DIR:-${HOME}/.local/share/eget/packages}"
readonly firefox_user_dir="${EXPLICIT_PACKAGE_FILE_WATCHER_FIREFOX_USER_DIR:-${HOME}/.mozilla/firefox}"
readonly obsidian_plugins_file="${EXPLICIT_PACKAGE_FILE_WATCHER_OBSIDIAN_PLUGINS_FILE:-${HOME}/Documents/notes/.obsidian/community-plugins.json}"
readonly uv_tools_dir="${EXPLICIT_PACKAGE_FILE_WATCHER_UV_TOOLS_DIR:-${XDG_DATA_HOME}/uv/tools}"
readonly vim_systemwide_plugin_dir="${EXPLICIT_PACKAGE_FILE_WATCHER_VIM_SYSTEMWIDE_PLUGIN_DIR:-/usr/share/vim/vimfiles/plugin}"
readonly vimplug_dir="${EXPLICIT_PACKAGE_FILE_WATCHER_VIMPLUG_DIR:-${HOME}/.vim/plugged}"
readonly pi_config_file="${EXPLICIT_PACKAGE_FILE_WATCHER_PI_CONFIG_FILE:-${HOME}/.pi/agent/settings.json}"

get_explicitly_installed_packages(){
    pikaur -Qqe
	jq -r -c '.addons[].id | "firefox:" + .' "${firefox_user_dir}"/*/addons.json
	jq -r -c '.installed | keys[] | "cura:" + .' "${cura_data_dir}"/*/packages.json
	jq -r -c '.[] | "obsidian:" + .' "${obsidian_plugins_file}"
	find "${vimplug_dir}" "${vim_systemwide_plugin_dir}" -mindepth 1 -maxdepth 1 -printf 'vim:%f\n'
	find "${eget_packages_dir}" -mindepth 1 -printf '%P\n'
	jq -r -c '.dependencies | keys | map("npm:" + .)[]' "${bun_package_file}"
	jq -r -c '.packages[]' "${pi_config_file}"
	ya pkg list | awk '/\(/ {print "yazi:" $1}'
	find "${uv_tools_dir}" -mindepth 1 -maxdepth 1 -type d -printf '%P\n' | awk -F'- ' '/^- / {print "uv:" $2}'
}

get_classified_packages(){
    readonly packages_to_not_monitor="${data_home}/packages-to-not-monitor"

    touch -a "${packages_to_monitor}" "${packages_to_not_monitor}"

    comm --output-delimiter=, <(sort -u "${packages_to_monitor}") <(sort -u "${packages_to_not_monitor}") |
    grep -vE '^$' |
    awk -F, '
        NF == 3 { print "ERROR: Package " $NF " is in both packages-to-monitor and packages-to-not-monitor" > "/dev/stderr"; next }
        { print $NF }
    '
}

get_files_to_monitor(){
    readonly data_home="${EXPLICIT_PACKAGE_FILE_WATCHER_DATA_DIR:-${XDG_CONFIG_HOME}/explicit-package-file-watcher}"
    readonly packages_to_monitor="${data_home}/packages-to-monitor"
    explicitly_installed_packages=$(get_explicitly_installed_packages | sort -u)
    classified_packages=$(get_classified_packages | sort -u)
    mkdir -p "${data_home}"

    comm -13 <(cat <<< "${explicitly_installed_packages}") <(cat <<< "${classified_packages}") |
    while read -r package; do echo "Package ${package} not installed" >&2; done

    comm --output-delimiter=, -2 <(cat <<< "${explicitly_installed_packages}") <(cat <<< "${classified_packages}") |
    awk -F, '
        NF == 1 { print "Package " $NF " has not been classified" > "/dev/stderr"; next }
        { print $NF }
    ' |
    comm -12 <(sort -) <(sort "${packages_to_monitor}") |
    xargs --no-run-if-empty pikaur -Qql |
    grep -v '/$' || [ $? = 1 ] # exclude folders and ignore grep exit code 1 (meaning no matches)
}

monitor(){
    exclude_nonexistent_files(){
        while read -r f; do
            if [ -f "${f}" ]; then
                echo "${f}"
            fi
        done
    }
    # shellcheck disable=SC2016
    exclude_nonexistent_files |
    xargs --no-run-if-empty -L 1000 -P0 inotifywait --quiet --monitor --format '%w%f' |
    xargs --no-run-if-empty -I{} bash -c 'echo $(date),{},"$(ps -o command= -f $(lsof -t {} || echo 0) 2>/dev/null)"'
}

main(){
    set -euo pipefail
    get_files_to_monitor |
    monitor
}

(return 2>/dev/null) || main
