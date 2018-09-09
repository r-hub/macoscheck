#! /bin/bash

set -euo pipefail

main() {
    declare filename="${1-}" pkgname="${2-}" rversion="${3-}" \
	    build="${4-}"

    # Everything relative to user's HOME
    cd

    # Allow falling back to source packages, unless the user overrides
    export R_COMPILE_AND_INSTALL_PACKAGES=always

    # Remotes config, do not use extra packages, do not error out on
    # warnings
    export R_REMOTES_STANDALONE=true
    export R_REMOTES_NO_ERRORS_FROM_WARNINGS=true

    # Set up environment variables
    # We need to export them, because R will run in a sub-shell
    # The rhubdummy variable is there, in case rhub-env.sh is empty,
    # and then export would just list the exported variables
    source rhub-env.sh
    export rhubdummy $(cut -f1 -d= < rhub-env.sh)

    # This is not in the PATH by default, it is here or there
    export PATH=$PATH:/Library/TeX/texbin:/usr/texbin:/usr/local/bin

    # Set R temporary directory
    mkdir $HOME/Rtemp
    export TMPDIR=$HOME/Rtemp

    echo "Setting up R environment"
    setup_r_environment

    echo "Setting up Xvfb"
    setup_xvfb

    if [[ "$build" == "true" ]]; then
	echo ">>>>>============== Running R CMD build"
	mkdir build
	cd build
	tar xzf "../$filename"
	R CMD build "${pkgname}"
	filename=$(ls *.tar.gz | head -1)
	cp "${filename}" ..
	cd ..
    fi

    echo ">>>>>============== Installing package dependencies"
    install_package_deps

    echo ">>>>>============== Running R CMD check"
    run_check
    echo ">>>>>============== Done with R CMD check"

    echo "Cleaning up Xvfb"
    cleanup_xvfb
}

setup_r_environment() {
    mkdir -p R
    echo >> .Rprofile 'options(repos = c(CRAN = "https://cran.r-hub.io"))'
    echo >> .Rprofile '.libPaths("~/R")'

    # BioC
    R -q -e "source('https://bioconductor.org/biocLite.R')"
    echo >> .Rprofile 'options(repos = BiocInstaller::biocinstallRepos())'
    echo >> .Rprofile 'unloadNamespace("BiocInstaller")'

    # locales
    export LC_ALL=en_US.UTF-8
    export LANG=en_US.UTF-8
}

install_package_deps() {
    # We download install-github.R first, in case the R version does not
    # support HTTPS. Then we install the proper 'remotes' package
    curl -OL https://raw.githubusercontent.com/r-pkgs/remotes/r-hub/install-github.R
    R -q -e 'source("install-github.R")$value("r-pkgs/remotes@r-hub")'

    # And the dependencies
    R -q -e "remotes::install_local('${filename}', dependencies = TRUE, INSTALL_opts = '--build')"
}

setup_xvfb() {
    # Random display between 1 and 100
    export DISPLAY=":$(($RANDOM / 331 + 1))"
    /opt/X11/bin/Xvfb "${DISPLAY}" -screen 0 1024x768x24 &
}

cleanup_xvfb() {
    killall -9 Xvfb || true
}

run_check() {
    R CMD check $checkArgs -l ~/R $filename
}

[[ "$0" == "$BASH_SOURCE" ]] && ( main "$@" )
