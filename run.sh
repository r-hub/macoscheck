#! /bin/bash

set -euo pipefail

main() {
  declare package="${1-}" jobid="${2-}" url="${3-}" rversion=${4-} \
          checkArgs="${5-}" envVars="${6-}"

  trap cleanup 0

  local password=$(random_password)
  username=$(random_username)
  homedir="/Users/${username}"

  echo "Creating user ${username}"
  create_user "${username}" "${password}" "${homedir}"

  echo "Downloading package"
  download_package

  echo "Setting up home directory"
  setup_home "${username}" "${homedir}" "${package}"

  echo "Querying R version"
  local realrversion=$(get_r_version "${rversion}")

  echo "Running check"
  local pkgname=$(echo ${package} | cut -d"_" -f1)
  run_check "${username}" "${package}" "${pkgname}" "${realrversion}"

  echo "Saving artifacts"
  save_artifacts "${jobid}" "${homedir}" "${pkgname}"

  # Cleanup is automatic
}

random_string() {
  declare n="${1-}"
  if [[ -z "$n" ]]; then echo no random string length; return 1; fi
  cat /dev/urandom | env LC_CTYPE=C tr -dc 'a-zA-Z0-9' | fold -w ${n} | head -n 1
}

random_username() {
  local random=$(random_string 8)
  echo "user${random}"
}

random_password() {
  echo $(random_string 16)
}

# This generates a UID that is larger than the current largest uid,
# and it has some randomness, to avoid race conditions. (Not perfect,
# but this is hard to solve without locking.)
generate_uid() {
  local maxid=$(dscl . -list /Users UniqueID | awk '{print $2}' | sort -ug |
    tail -1)
  jot -r 1 $((maxid + 1)) $((maxid + 10))
}

# Create a random user, with restricted access, mavericks does not have
# sysadminctl, so we need to do everything manually. The most annoying
# part is that the OS cannot pick a uid for us, but we need to pick one
# manually, see `generate_uid()`
create_user_old() {
  declare username="${1-}" password="${2-}" homedir="${3-}"
  local uid=$(generate_uid)

  dscl . -create "/Users/${username}"
  dscl . -create "/Users/${username}" UniqueID "${uid}"
  dscl . -create "/Users/${username}" NFSHomeDirectory ${homedir}
  dscl . -passwd "/Users/${username}" "${password}"
}

# We use sysadminctl, even if it requires some manual work anyway, because
# it seems to pick a uid for us. Hopefully it does not have race conditions
# when doing this.
create_user_new() {
  declare username="${1-}" password="${2-}" homedir="${3-}"
  sysadminctl -addUser "${username}" -password "${password}" -home "${homedir}"
}

setup_user() {
  declare username="${1-}"
  dscl . -create "/Users/${username}" PrimaryGroupID 600
  dscl . -create "/Users/${username}" UserShell /bin/bash
  dscl . -create "/Users/${username}" RealName "R-hub job user"
  dscl . -create /Users/"${username}" dsAttrTypeNative:_defaultLanguage en
  dscl . -create /Users/"${username}" dsAttrTypeNative:_guest true
  dscl . -create /Users/"${username}" dsAttrTypeNative:_writers__defaultLanguage "${username}"
  dscl . -create /Users/"${username}" dsAttrTypeNative:_writers_UserCertificate "${username}"
  dscl . -create /Users/"${username}" AuthenticationHint ''
  dscl . -create /Users/"${username}" Picture "/Library/User Pictures/Nature/Leaf.tif"
  dscl . -create /Users/"${username}" RecordName "${username}"
}

ensure_guest_group() {
  if dscl . -list /Groups PrimaryGroupID | awk '{print $2;}' | grep -q '^600$'; then
    echo "Guest group exists"
  else
    echo "Adding guest group"
    dscl . -create /groups/rhubguest
    dscl . -append /groups/rhubguest PrimaryGroupID 600
    dscl . -append /groups/rhubguest passwd "*"
  fi
}

create_user() {
  declare username="${1-}" password="${2-}" homedir="${3-}"
  local osversion=$(sw_vers -productVersion | awk -F. '{print $2}')

  ensure_guest_group

  if [[ "$osversion" -lt 10 ]]; then
    create_user_old "$username" "$password" "$homedir"
  else
    create_user_new "$username" "$password" "$homedir"
  fi

  setup_user "$username"
}

download_package() {
  curl -L -o "$package" "${url}"
}

setup_home() {
  declare username="${1-}" homedir="${2-}" package="${3-}"
  mkdir "${homedir}"
  cp "${package}" "${homedir}"
  chown "${username}":600 "${homedir}"
  chmod 700 "${homedir}"
}

json_version() {
  declare url="${1-}"
  local version=$(curl -s "${url}" | ./JSON.sh -b |
    grep '^\[0,"version"\]' | awk '{ print $2; }' | tr -d '"')
  echo "${version}"
}

# Get the exact R version to use from the R version string of the platform
get_r_version() {
  declare rversion="${1-}"
  if [[ "${rversion}" == "r-devel" ]]; then
    realrversion="devel"
  elif [[ "${rversion}" == "r-release" ]]; then
    realrversion=$(json_version "https://rversions.r-pkg.org/r-release-macos")
  elif [[ "${rversion}" == "r-patched" ]]; then
    realrversion=$(json_version "https://rversions.r-pkg.org/r-release-macos")
    realrversion="${realrversion}patched"
  elif [[ "${rversion}" == "r-oldrel" ]]; then
    realrversion=$(json_version "https://rversions.r-pkg.org/r-oldrel")
  else
    realrversion="${rversion}"
  fi
  echo "${realrversion}"
}

run_check() {
  declare username="${1-}" filename="${2-}" pkgname="${3-}" rversion="${4-}"
  su -l "${username}" \
    -c "cd $(pwd); ./slave.sh ${filename} ${pkgname} ${rversion}" || true
}

save_artifacts() {
    declare jobid="${1-}" homedir="${2-}" pkgname="${3-}"
    mkdir -p "${jobid}"
    cp -r "${homedir}/${pkgname}.Rcheck" "${jobid}" || true
    cp -r "${homedir}/"*.tgz "${jobid}" || true
}

# Cleanup user, including home directory, arguments are global,
# because we are calling this from trap
cleanup() {
  echo "Cleaning up user and home directory"
  if [[ -z "$username" || -z "$homedir" ]]; then
    echo "Cannot clean up, no username or homedir set"
    return 1
  fi
  dscl . -delete /Users/"${username}"
  rm -rf "${homedir}"
}

[[ "$0" == "$BASH_SOURCE" ]] && main "$@"
