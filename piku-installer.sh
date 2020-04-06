#!/usr/bin/env bash 
set -e  # exit on error

BB_LOG_USE_COLOR=true

BASHBOOSTER_URL=https://bitbucket.org/kr41/bash-booster/downloads/bashbooster-0.6.zip 
PIKU_URL=https://raw.githubusercontent.com/jsenin/piku/master/piku.py
ACME_URL=https://get.acme.sh


function finish {
  # Your cleanup code here
	echo ""
	echo "Installation failed."
	echo "[!] Deleting piku user"
	userdel piku
	echo "[!] Deleting piku uwsgi-piku"
  rm /usr/local/bin/uwsgi-piku
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
		echo 'Error: unzip is not installed.' >&2
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
bb-apt-install nginx incron acl cron anacron socat

cat <<EOF > /etc/default/locale
LC_ALL=C.UTF-8
LANG=C.UTF-8
EOF

bb-log-info "Creating piku user"
# add user
useradd piku --create-home --password \! --shell /bin/bash --groups www-data --comment "PaaS access"

bb-log-info "Installing piku requirements"
# python packages 
pip3 install setuptools click==7.0 virtualenv==15.1.0 uwsgi==2.0.15


ln -s $(which uwsgi) /usr/local/bin/uwsgi-piku
curl --silent --location https://raw.githubusercontent.com/piku/piku/master/uwsgi-piku.dist --output /etc/init.d/uwsgi-piku 
curl --silent --location https://raw.githubusercontent.com/piku/piku/master/uwsgi-piku.service --output /etc/systemd/system/uwsgi-piku.service
update-rc.d uwsgi-piku defaults
chmod +x /etc/init.d/uwsgi-piku
# /etc/init.d/uwsgi-piku enable

curl --silent --location https://raw.githubusercontent.com/piku/piku/master/nginx.default.dist --output /etc/nginx/sites-available/default
/etc/init.d/nginx start
update-rc.d nginx defaults

curl --silent --location https://raw.githubusercontent.com/piku/piku/master/incron.dist --output /etc/incron.d/piku
/etc/init.d/incron start
update-rc.d incron defaults

bb-log-info "Download Piku"
# bb-download $PIKU_URL  requires wget
curl --silent --location ${PIKU_URL} --output /home/piku/piku.py
chmod +x /home/piku/piku.py
chown piku.piku -R /home/piku


bb-log-info "Configure Piku"
su -c 'LC_ALL=C.UTF-8 LANG=C.UTF-8 python3 /home/piku/piku.py setup' piku
cp /root/.ssh/authorized_keys /tmp/id_rsa.pub
su -c 'LC_ALL=C.UTF-8 LANG=C.UTF-8 python3 /home/piku/piku.py setup:ssh /tmp/id_rsa.pub' piku
rm /tmp/id_rsa.pub

bb-log-info "Download ACME (letscrypt certs tool)"
curl --silent --location ${ACME_URL} --output /home/piku/acme.sh

bb-log-info "Install ACME"
bash /home/piku/acme.sh --install --home /home/piku/.acme.sh
