#!/usr/bin/env bash
#
# VGH bootstrap script
#
# USAGE:
# https://github.com/vladgh/puppet.git
# bash puppet/bootstrap.sh --role=myrole --env=production

# DEFAULTS
ROLE='none'
ENVIRONMENT='production'
PUPPET_COLLECTION='pc1'

# Wrap the entire script inside a function to make sure that, when piped, it's
# retrieved completely
bootstrap(){

# Immediately exit on errors
set -euo pipefail

# Parse command line arguments
for var in "$@"; do
  if [[ "$var" =~ --role=.* ]]; then
    ROLE=${var//--role=/}
  elif [[ "$var" =~ --env=.* ]]; then
    ENVIRONMENT=${var//--env=/}
  fi
done

# VARs
PATH=/opt/puppetlabs/bin:/opt/puppetlabs/puppet/bin:$PATH
TEMPDIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'tmp')
ROOTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

# Check if command exists
is_cmd() { command -v "$@" >/dev/null 2>&1 ;}
# Release is Ubuntu
is_ubuntu() { is_cmd lsb_release && [[ "$(lsb_release -si)" =~ Ubuntu ]] ;}
# Get codename
codename() { is_cmd lsb_release && lsb_release -cs ;}
# APT install package
apt_install(){ echo "Installing $*" && sudo apt-get -qy install "$@" < /dev/null ;}
# Update APT
apt_update() { echo 'Updating APT' && sudo apt-get -qy update < /dev/null ;}
# Upgrade system
apt_upgrade(){ echo 'Upgrading system' && sudo apt-get -qy upgrade < /dev/null ;}
# Puppet apply
puppet_apply() {
  puppet apply \
    --verbose \
    --modulepath="${ROOTDIR}/modules" \
    --environment="${ENVIRONMENT}" \
    "$@"
}
# Puppet module install
puppet_mod_install(){
  puppet module install --modulepath="${ROOTDIR}/modules" "$@"
}

# Update/upgrade system
apt_update && apt_upgrade

# Install essential packages
apt_install \
  wget \
  curl \
  libffi-dev \
  libssl-dev \
  python-pip \
  python-dev \
  software-properties-common

# Install Puppet release package
if is_cmd puppet; then
  echo "Puppet $(puppet --version) is already installed"
else
  echo 'Installing Puppet release package'
  debname="puppetlabs-release-${PUPPET_COLLECTION}-$(codename).deb"
  debfile="${TEMPDIR}/${debname}"
  wget -qO "$debfile" "https://apt.puppetlabs.com/${debname}"
  sudo dpkg -i "$debfile"
  apt_update && apt_install puppet-agent
fi

# Install temporary bootstrap modules
puppet_mod_install puppetlabs-apt --version 2.2.0
puppet_mod_install puppetlabs-git --version 0.4.0
puppet_mod_install zack-r10k --version 3.1.1
puppet_mod_install hunner-hiera --version 1.3.2

# Add external Facter facts
factsdir='/etc/puppetlabs/facter/facts.d'
mkdir -p "$factsdir"
echo "role: ${ROLE}" > "${factsdir}/role.yaml"

# Apply bootstrap manifest
echo 'Apply bootstrap manifest'
puppet_apply "${ROOTDIR}/manifests/bootstrap.pp"

# Deploy R10K environaments
echo 'Deploy R10k environments'
r10k deploy environment --puppetfile --verbose --color

# Apply main Puppet manifest
echo 'Apply main Puppet manifest'
puppet_apply \
  "$(puppet config print manifest --environment="${ENVIRONMENT}")/site.pp"

} # end bootstrap function

# RUN
bootstrap "$@"

