#! /bin/bash

sourced=0
if [ -n "$ZSH_EVAL_CONTEXT" ]; then
    case $ZSH_EVAL_CONTEXT in *:file) sourced=1;; esac
elif [ -n "$KSH_VERSION" ]; then
    [ "$(cd $(dirname -- $0) && pwd -P)/$(basename -- $0)" != "$(cd $(dirname -- ${.sh.file}) && pwd -P)/$(basename -- ${.sh.file})" ] && sourced=1
elif [ -n "$BASH_VERSION" ]; then
    (return 0 2>/dev/null) && sourced=1
else
    # All other shells: examine $0 for known shell binary filenames
    # Detects `sh` and `dash`; add additional shell filenames as needed.
    case ${0##*/} in sh|dash) sourced=1;; esac
fi

function install_brew() {
    (
	set -e
	if /usr//bin/which -s brew; then return; fi
	export CI=true
	/bin/bash -c \
	    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
    )
}

function update_sysreqs() {
    (
	set -e
	echo "== UPDATING BREW ======================"
	brew update

	brew cask install homebrew/cask-versions/adoptopenjdk8
	forms=$(cat sysreqs.txt)
	for f in $forms; do
	    echo "-- INSTALLING $f --"
	    brew install $f
	    brew upgrade $f
	done
    )
}

function install_r() {
    true
}

function main() {
    true
}

if [ "$sourced" = "0" ]; then
    set -e
    main
fi
