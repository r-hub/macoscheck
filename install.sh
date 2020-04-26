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
    echo "== INSTALLING BREW ================================"
    (
	set -e
	if /usr//bin/which -s brew; then return; fi
	export CI=true
	/bin/bash -c \
	    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
    )
}

function update_sysreqs() {
    echo "== UPDATING SYSREQS ==============================="
    (
	set -e
	forms=$(cat sysreqs.txt)
	brew install $forms
    )
}

function install_xquartz() {
    echo "== INSTALLING XQUARTZ ============================="
    (
	set -e
	if (pkgutil --pkgs | grep -q org.macosforge.xquartz.pkg); then
	    return;
	fi
	local version=2.7.11
	curl -C - -L -O -f \
	    https://dl.bintray.com/xquartz/downloads/XQuartz-${version}.dmg
	sudo hdiutil attach XQuartz-${version}.dmg
	sudo installer -package /Volumes/XQuartz-${version}/XQuartz.pkg \
	    -target /
	sudo hdiutil detach /Volumes/XQuartz-${version}
    )
}

function install_r() {
    echo "== INSTALLING R ${1} =============================="
    (
	set -e
	local version="$1"
	url="https://cloud.r-project.org/bin/macosx/R-${version}.pkg"
	ur2="https://cloud.r-project.org/bin/macosx/old/R-${version}.pkg"
	curl -C - -O -f "$url" || curl -C - -O -f "$ur2"
	sudo installer -pkg "R-${version}.pkg" -target /
    )
}

function install_java() {
    echo "== INSTALLING JAVA ================================"
    brew cask install java
}

function install_tex() {
    echo "== INSTALLING TEX ================================="
    brew cask install mactex-no-gui
}

function install_r_hub_client() {
    curl -O -C - https://repo.jenkins-ci.org/releases/org/jenkins-ci/plugins/swarm-client/2.2/swarm-client-2.2-jar-with-dependencies.jar
}

function install_gfortran_82() {
    echo "== INSTALLING GFORTRAN 8.2 ========================"
    (
	set -e
	curl -L -O -f -C - https://github.com/fxcoudert/gfortran-for-macOS/releases/download/8.2/gfortran-8.2-Mojave.dmg
	sudo hdiutil attach gfortran-8.2-Mojave.dmg
	sudo installer -package \
	    /Volumes/gfortran-8.2-Mojave/gfortran-8.2-Mojave/gfortran.pkg \
	    -target /
	sudo hdiutil detach /Volumes/gfortran-8.2-Mojave
    )
}

function main() {
    install_xquartz
    install_brew
    update_sysreqs
    install_java
    install_r 4.0.0
    install_gfortran_82
    install_r_hub_client
}

if [ "$sourced" = "0" ]; then
    set -e
    main
fi
