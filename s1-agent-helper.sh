#!/bin/bash
################################################################################
# Description:  Bash script to aid with automating S1 Agent install on Linux
# 
# Usage:    sudo ./s1-agent-helper.sh S1_CONSOLE_PREFIX API_KEY SITE_TOKEN VERSION_STATUS
# 
# Version:  1.4
################################################################################

# NOTE:  This version will install the latest EA or GA version of the S1 agent
# NOTE:  This script will install the curl and jq utilities if not already installed.


S1_MGMT_URL="https://$1.sentinelone.net"    #ie:  usea1-purple
API_ENDPOINT='/web/api/v2.1/update/agent/packages'
API_KEY=$2
SITE_TOKEN=$3
VERSION_STATUS=$4   # "EA" or "GA"
CURL_OPTIONS='--silent --tlsv1.2'
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
        if [[ $1 = '.deb' ]]; then
            sudo apt-get update && sudo apt-get install -y curl
        elif [[ $1 = '.rpm' ]]; then
            sudo yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
            sudo yum install -y jq
        else
            echo "unsupported file extension!" # Note.. might need to handle dnf in the future
        fi
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
if [[ ${VERSION_STATUS} != "GA" && "$VERSION_STATUS" != "EA" ]]; then
    echo "Invalid format for VERSION_STATUS: $VERSION_STATUS"
    echo "The value of VERSION_STATUS must be either 'EA' or 'GA'"
    exit 1
fi


function jq_check () {
    if ! [[ -x "$(which jq)" ]]; then
        echo ""
        echo "################################################################################"
        echo "# INSTALLING JQ UTILITY IN ORDER TO PARSE JSON RESPONSES FROM API"
        echo "################################################################################"
        echo ""
        if [[ $1 = '.deb' ]]; then
            sudo yum update -y
        elif [[ $1 = '.rpm' ]]; then
            sudo yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
            sudo apt-get update && sudo apt-get install -y jq
            sudo yum install -y jq
        else
            echo "unsupported file extension!" # Note.. might need to handle dnf in the future
        fi 
    else
        echo "jq is already installed... :)"
    fi
}


function get_latest_version () {
    for i in {0..9}; do
        s=$(cat response.txt | jq -r ".data[$i].status")
        if [[ $s = $VERSION_STATUS ]]; then
            AGENT_FILE_NAME=$(cat response.txt | jq -r ".data[$i].fileName")
            AGENT_DOWNLOAD_LINK=$(cat response.txt | jq -r ".data[$i].link")
            break
        fi
    done
}


# Detect if the Linux Platform uses RPM or DEB packages
if (type lsb_release &>/dev/null); then
    FILE_EXTENSION='.deb'
    curl_check $FILE_EXTENSION
    jq_check $FILE_EXTENSION
    sudo curl -H "Accept: application/json" -H "Authorization: ApiToken $API_KEY" "$S1_MGMT_URL$API_ENDPOINT?countOnly=false&packageTypes=Agent&osTypes=linux&sortBy=createdAt&limit=10&fileExtension=.deb&sortOrder=desc" > response.txt
    get_latest_version
    sudo curl -H "Authorization: ApiToken $API_KEY" $AGENT_DOWNLOAD_LINK -o /tmp/$AGENT_FILE_NAME
    sudo dpkg -i /tmp/$AGENT_FILE_NAME
    sudo /opt/sentinelone/bin/sentinelctl management token set $SITE_TOKEN
    sudo /opt/sentinelone/bin/sentinelctl control start
else
    FILE_EXTENSION='.rpm'
    curl_check $FILE_EXTENSION
    jq_check $FILE_EXTENSION
    sudo curl -H "Accept: application/json" -H "Authorization: ApiToken $API_KEY" "$S1_MGMT_URL$API_ENDPOINT?countOnly=false&packageTypes=Agent&osTypes=linux&sortBy=createdAt&limit=10&fileExtension=.rpm&sortOrder=desc" > response.txt
    get_latest_version
    sudo curl -H "Authorization: ApiToken $API_KEY" $AGENT_DOWNLOAD_LINK -o /tmp/$AGENT_FILE_NAME
    sudo rpm -i --nodigest /tmp/$AGENT_FILE_NAME
    sudo /opt/sentinelone/bin/sentinelctl management token set $SITE_TOKEN
    sudo /opt/sentinelone/bin/sentinelctl control start
fi

#clean up files..
rm -f response.txt
rm -f /tmp/$AGENT_FILE_NAME
