#! /bin/bash

set -euo pipefail

main() {
    declare filename="${1-}" pkgname="${2-}" rversion="${3-}"

    # Everything relative to user's HOME
    cd

    # This is not in the PATH by default, it is here or there
    export PATH=$PATH:/Library/TeX/texbin:/usr/texbin

    # Set R temporary directory
    mkdir $HOME/Rtemp
    export TMPDIR=$HOME/Rtemp

    echo "Setting up R environment"
    setup_r_environment

    echo "Installing package dependencies"
    install_package_deps

    echo "Running check"
    run_check
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
    curl -OL https://raw.githubusercontent.com/r-pkgs/remotes/master/install-github.R
    R -q -e 'source("install-github.R")$value("r-pkgs/remotes")'

    # And the dependencies
    R -q -e "remotes::install_local('${filename}', dependencies = TRUE)"
}

run_check() {
    R CMD check -l ~/R $filename
}

[[ "$0" == "$BASH_SOURCE" ]] && ( main "$@" )
