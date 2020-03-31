#!/bin/bash
################################################################################
# Description:  Bash script to aid with automating S1 Agent install on Linux
# 
# Usage:        sudo ./s1-agent-helper.sh AGENT_VERSION SITE_TOKEN
# 
# Version:      1.1
################################################################################
# Note: Currently using GitHub to serve up Agent packages.
AGENT_GITHUB_REPO='https://github.com/howie-howerton/s1-agents/blob/master/'  
GITHUB_RAW_POSTFIX='?raw=true'
AGENT_VERSION=$1
SITE_TOKEN=$2
CURL_OPTIONS='--silent --tlsv1.2'
PKG_BASE_NAME=''

# Check if running as root
if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "This script must be run as root.  Please retry with 'sudo'."
    exit 1;
fi

# Check if correct # of arguments are passed.
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 AGENT_VERSION SITE_TOKEN" >&2
  exit 1
fi

for i in $VALID_VERSIONS[@]
do 
    echo $i
done

# Get the proper package name from the AGENT_VERSION argument
VERSION=$(echo $AGENT_VERSION | tr '.' '_')
# Next, check if the requested version is valid or not (NOTE: THIS LIST WILL NEED TO BE UPDATED AS NEW AGENTS ARE RLEASED!)
if ! [[ "$VERSION" =~ ^(4_0_3_11|4_0_2_6|3_5_2_6|3_4_5_3|3_3_1_14) ]]; then
    echo "Invalid version specified: $VERSION"
    echo "Valid versions are:  4.0.3.11, 4.0.2.6, 3.5.2.6, 3.4.5.3 and 3.3.1.14"
    exit 1
else
    PKG_BASE_NAME=SentinelAgent_linux_v$VERSION
    echo $PKG_BASE_NAME
fi

# Check if curl is installed.
if ! [[ -x "$(which curl)" ]]; then
  echo "curl is not installed.  Please install curl and retry."
  exit 1
fi

# Check if the SITE_TOKEN is in the right format
if ! [[ ${#SITE_TOKEN} -eq 108 ]]; then
    echo "Invalid format for SITE_TOKEN: $SITE_TOKEN"
    echo "Site Tokens are generally 108 characters long and are ASCII encoded."
    exit 1
fi

# Detect if the Linux Platform uses RPM or DEB packages
if (type lsb_release &>/dev/null); then
    sudo curl -L "$AGENT_GITHUB_REPO$PKG_BASE_NAME.deb$GITHUB_RAW_POSTFIX" -o /tmp/$PKG_BASE_NAME.deb
    sudo dpkg -i /tmp/$PKG_BASE_NAME.deb
    sudo /opt/sentinelone/bin/sentinelctl management token set $SITE_TOKEN
    sudo /opt/sentinelone/bin/sentinelctl control start
else
    sudo curl -L "$AGENT_GITHUB_REPO$PKG_BASE_NAME.rpm$GITHUB_RAW_POSTFIX" -o /tmp/$PKG_BASE_NAME.rpm
    sudo rpm -i --nodigest /tmp/$PKG_BASE_NAME.rpm
    sudo /opt/sentinelone/bin/sentinelctl management token set $SITE_TOKEN
    sudo /opt/sentinelone/bin/sentinelctl control start
fi




