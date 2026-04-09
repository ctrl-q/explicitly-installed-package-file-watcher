#!/bin/bash
set -e
set -o nounset
set -o pipefail
readonly data_home="${XDG_CONFIG_HOME}/explicit-package-file-watcher"
readonly firefox_user_dir=/home/owner/.mozilla/firefox
readonly obsidian_plugins_file=/home/owner/Documents/notes/.obsidian/community-plugins.json
readonly cura_data_dir=/home/owner/.local/share/cura/
readonly eget_packages_dir=/home/owner/.local/share/eget/packages
readonly vimplug_dir=/home/owner/.vim/plugged
readonly vim_systemwide_plugin_dir=/usr/share/vim/vimfiles/plugin

get_files_to_monitor(){
    local -r packages_to_monitor="${data_home}/packages-to-monitor"
    local -r packages_to_not_monitor="${data_home}/packages-to-not-monitor"

    get_explicitly_installed_packages(){
        pikaur -Qqe
	jq -r -c '.addons[].id | "firefox:" + .' "${firefox_user_dir}"/*/addons.json
	jq -r -c '.installed | keys[] | "cura:" + .' "${cura_data_dir}"/*/packages.json
	jq -r -c '.[] | "obsidian:" + .' "${obsidian_plugins_file}"
	find "${vimplug_dir}" "${vim_systemwide_plugin_dir}" -mindepth 1 -maxdepth 1 -printf 'vim:%f\n'
	find "${eget_packages_dir}" -mindepth 1 -printf '%P\n'
	jq -r -c '.dependencies | keys | map("npm:" + .)[]' /home/owner/.cache/.bun/install/global/package.json
	ya pkg list | awk '/\(/ {print "yazi:" $1}'
    }

    get_classified_packages(){
        touch -a "${packages_to_monitor}" "${packages_to_not_monitor}"

        comm --output-delimiter=, <(sort -u "${packages_to_monitor}") <(sort -u "${packages_to_not_monitor}") |
        grep -vE '^$' |
        awk -F, '
            NF == 3 { print "ERROR: Package " $NF " is in both packages=to-monitor and packages-to-not-monitor" > "/dev/stderr"; next }
            { print $NF }
        '
    }

    comm -13 <(get_explicitly_installed_packages | sort -u) <(get_classified_packages | sort -u) |
    while read -r package; do echo "INFO: Package ${package} not installed" >&2; done

    comm --output-delimiter=, -2 <(get_explicitly_installed_packages | sort -u) <(get_classified_packages | sort -u) |
    awk -F, '
        NF == 1 { print "INFO: Package " $NF " has not been classified" > "/dev/stderr"; next }
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
    exclude_nonexistent_files |
    xargs --no-run-if-empty -L 1000 -P0 inotifywait --quiet --monitor --format '%w%f' |
    xargs --no-run-if-empty -I{} bash -c 'echo $(date),{},"$(ps -o command= -f $(lsof -t {} || echo 0) 2>/dev/null)"'
}

main(){
    mkdir -p "${data_home}"
    get_files_to_monitor |
    monitor
}

(return 2>/dev/null) || main
