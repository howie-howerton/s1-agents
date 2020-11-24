#!/bin/bash
################################################################################
# Description:  Bash script to aid with automating S1 Agent install on Linux
# 
# Usage:    sudo ./s1-agent-helper.sh S1_CONSOLE_PREFIX API_KEY SITE_TOKEN VERSION_STATUS
# 
# Version:  1.5
################################################################################

# NOTE:  This version will install the latest EA or GA version of the S1 agent
# NOTE:  This script will install the curl and jq utilities if not already installed.


S1_MGMT_URL="https://$1.sentinelone.net"    #ie:  usea1-purple
API_ENDPOINT='/web/api/v2.1/update/agent/packages'
API_KEY=$2
SITE_TOKEN=$3
VERSION_STATUS=$4   # "EA" or "GA"
CURL_OPTIONS='--silent --tlsv1.2'
FILE_EXTENSION=''
PACKAGE_MANAGER=''
AGENT_INSTALL_SYNTAX=''
AGENT_FILE_NAME=''
AGENT_DOWNLOAD_LINK=''

# Check if running as root
if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "This script must be run as root.  Please retry with 'sudo'."
    exit 1;
fi

# Check if correct # of arguments are passed.
if [ "$#" -ne 4 ]; then
  echo "Usage: $0 S1_CONSOLE_PREFIX API_KEY SITE_TOKEN VERSION_STATUS" >&2
  exit 1
fi

# Check if curl is installed.
function curl_check () {
    if ! [[ -x "$(which curl)" ]]; then
    echo ""
        echo "################################################################################"
        echo "# INSTALLING CURL UTILITY IN ORDER TO INTERACT WITH S1 API"
        echo "################################################################################"
        echo ""
        if [[ $1 = 'apt' ]]; then
            sudo apt-get update && sudo apt-get install -y curl
        elif [[ $1 = 'yum' ]]; then
            sudo yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
            sudo yum install -y curl
        elif [[ $1 = 'zypper' ]]; then
            sudo zypper install -y curl
        elif [[ $1 = 'dnf' ]]; then
            sudo dnf install -y curl
        else
            echo "unsupported file extension!" # Note.. might need to handle dnf in the future
        fi
    else
        echo "curl is already installed... :)"
    fi
}

# Check if the SITE_TOKEN is in the right format
if ! [[ ${#SITE_TOKEN} -gt 100 ]]; then
    echo "Invalid format for SITE_TOKEN: $SITE_TOKEN"
    echo "Site Tokens are generally more than 100 characters long and are ASCII encoded."
    exit 1
fi

# Check if the API_KEY is in the right format
if ! [[ ${#API_KEY} -eq 80 ]]; then
    echo "Invalid format for API_KEY: $API_KEY"
    echo "API Keys are generally 80 characters long and are alphanumeric."
    exit 1
fi

# Check if the VERSION_STATUS is in the right format
if [[ ${VERSION_STATUS} != *"GA"* && "$VERSION_STATUS" != *"EA"* ]]; then
    echo "Invalid format for VERSION_STATUS: $VERSION_STATUS"
    echo "The value of VERSION_STATUS must contain either 'EA' or 'GA'"
    exit 1
fi


function jq_check () {
    if ! [[ -x "$(which jq)" ]]; then
        echo ""
        echo "################################################################################"
        echo "# INSTALLING JQ UTILITY IN ORDER TO PARSE JSON RESPONSES FROM API"
        echo "################################################################################"
        echo ""
        if [[ $1 = 'apt' ]]; then
            sudo apt-get update && sudo apt-get install -y jq
        elif [[ $1 = 'yum' ]]; then
            sudo yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
            sudo yum install -y jq
        elif [[ $1 = 'zypper' ]]; then
            sudo zypper install -y jq
        elif [[ $1 = 'dnf' ]]; then
            sudo dnf install -y jq
        else
            echo "unsupported file extension!" # Note.. might need to handle dnf in the future
        fi 
    else
        echo "jq is already installed... :)"
    fi
}


function get_latest_version () {
    for i in {0..20}; do
        s=$(cat response.txt | jq -r ".data[$i].status")
        if [[ $s == *$VERSION_STATUS* ]]; then
            AGENT_FILE_NAME=$(cat response.txt | jq -r ".data[$i].fileName")
            AGENT_DOWNLOAD_LINK=$(cat response.txt | jq -r ".data[$i].link")
            break
        fi
    done
}


# Detect if the Linux Platform uses RPM/DEB packages and the correct Package Manager to use
if (cat /etc/*release |grep 'ID=ubuntu' || cat /etc/*release |grep 'ID=debian'); then
    FILE_EXTENSION='.deb'
    PACKAGE_MANAGER='apt'
    AGENT_INSTALL_SYNTAX='dpkg -i'
elif (cat /etc/*release |grep 'ID="rhel"' || cat /etc/*release |grep 'ID="amzn"' || cat /etc/*release |grep 'ID="centos"'); then
    FILE_EXTENSION='.rpm'
    PACKAGE_MANAGER='yum'
    AGENT_INSTALL_SYNTAX='rpm -i --nodigest'
elif (cat /etc/*release |grep 'ID="sles"'); then
    FILE_EXTENSION='.rpm'
    PACKAGE_MANAGER='zypper'
    AGENT_INSTALL_SYNTAX='rpm -i --nodigest'
elif (cat /etc/*release |grep 'ID="fedora"' || cat /etc/*release |grep 'ID=fedora'); then
    FILE_EXTENSION='.rpm'
    PACKAGE_MANAGER='dnf'
    AGENT_INSTALL_SYNTAX='rpm -i --nodigest'
else
    echo "Unknown Release ID"
    cat /etc/*release
fi

curl_check $PACKAGE_MANAGER
jq_check $PACKAGE_MANAGER
sudo curl -H "Accept: application/json" -H "Authorization: ApiToken $API_KEY" "$S1_MGMT_URL$API_ENDPOINT?countOnly=false&packageTypes=Agent&osTypes=linux&sortBy=createdAt&limit=20&fileExtension=$FILE_EXTENSION&sortOrder=desc" > response.txt
get_latest_version
sudo curl -H "Authorization: ApiToken $API_KEY" $AGENT_DOWNLOAD_LINK -o /tmp/$AGENT_FILE_NAME
sudo $AGENT_INSTALL_SYNTAX -i /tmp/$AGENT_FILE_NAME
sudo /opt/sentinelone/bin/sentinelctl management token set $SITE_TOKEN
sudo /opt/sentinelone/bin/sentinelctl control start

#clean up files..
rm -f response.txt
rm -f /tmp/$AGENT_FILE_NAME
