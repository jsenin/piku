#!/usr/bin/env bash 
set -e  # exit on error

BASHBOOSTER_URL=https://bitbucket.org/kr41/bash-booster/downloads/bashbooster-0.6.zip 
PIKU_URL=https://raw.githubusercontent.com/jsenin/piku/master/piku.py
ACME_UR_=https://raw.githubusercontent.com/Neilpang/acme.sh/6ff3f5d/acme.sh


function finish {
  # Your cleanup code here
	echo ""
	echo "Installation failed."
	echo "[!] Deleting piku user"
	userdel piku
}
trap finish EXIT
trap finish ERR


function __get_bb {
	if [ -f "bashbooster.sh" ]; then
		return
	fi;
 
	echo "Downloading bashbooster"

	if ! [ -x "$(command -v curl)" ]; then
		echo 'Error: curl is not installed.' >&2
		exit 1
	fi

	if ! [ -x "$(command -v unzip)" ]; then
		echo 'Error: curl is not installed.' >&2
		exit 1
	fi

	curl --silent --location ${BASHBOOSTER_URL} --output bashbooster-0.6.zip
	unzip -j bashbooster-0.6.zip bashbooster-0.6/bashbooster.sh

}

## main ----------------------

__get_bb

unset CDPATH
cd "$( dirname "${BASH_SOURCE[0]}" )"

source bashbooster.sh

bb-log-info "Piku installer"
bb-log-info "Installing core packages"

bb-apt-install bc git build-essential libpcre3-dev zlib1g-dev 
# bb-apt-install python2 python2-pip python2-dev python2-setuptools 
bb-apt-install python3 python3-pip python3-dev python3-setuptools 
bb-apt-install nginx incron acl

bb-log-info "Creating piku user"
# add user
useradd piku --password \! --shell /bin/false --groups www-data --comment "PaaS access"

bb-log-info "Installing piku requirements"
# python packages 
pip3 install setuptools click==7.0 virtualenv==15.1.0 uwsgi==2.0.15

bb-log-info "Download Piku"
# bb-download $PIKU_URL  requires wget
curl --silent --location ${PIKU_URL} --output /home/piku/piku.py

bb-log-info "Configure Piku"
python3 /home/piku/piku.py setup
python3 /home/piku/piku.py setup:ssh /root/.ssh/authorized_keys

bb-log-info "Download ACME (letscrypt certs tool)"
curl --silent --localtion ${ACME_URL} --output /home/piku/acme.sh

bb-log-info "Install ACME"
bash /home/piku/acme.sh --install

# ngnix
# incron service
