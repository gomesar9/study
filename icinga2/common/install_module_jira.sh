#!/bin/bash

source install-icinga-module


if [ $(icingacli module list | grep -c 'ipl') -ne 1 ]; then
    echo "Installing ipl module"
    install_module "ipl" "v0.4.0"
fi

if [ $(icingacli module list | grep -c 'incubator') -ne 1 ]; then
    echo "Installing incubator module"
    install_module "incubator" "v0.5.0"
fi

echo "Installing jira module"
ICINGAWEB_MODULEPATH="/usr/share/icingaweb2/modules"
REPO_URL="https://github.com/Icinga/icingaweb2-module-jira"
TARGET_DIR="${ICINGAWEB_MODULEPATH}/jira"
MODULE_VERSION="1.0.0"

git_cmd=$(command -v git)
if [ $? -ne 0 ]; then
    echo "Git not found. Trying to install.."
    apt install git
fi
git clone "${REPO_URL}" "${TARGET_DIR}" --branch "v${MODULE_VERSION}"

echo "Enabling jira module"

install -d -m 2770 -o www-data -g icingaweb2 /etc/icingaweb2/modules/jira
> /etc/icingaweb2/modules/jira cat << EOF
[api]
host = "jira.example.com"
; port = 443
; path = "/"
; scheme = "https"
username = "icinga"
password = "***"

[ui]
; default_project = "SO"
; default_issuetype = "Event"

[icingaweb]
url = "https://icinga.example.com/icingaweb2"
EOF
usermod -a -G icingaweb2 nagios

icingacli module enable jira
service icinga2 restart
