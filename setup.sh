#!/bin/bash
set -e
set -x

# Install dependencies
sudo apt-get install -y python3 busybox-static fakeroot git dmsetup kpartx netcat-openbsd nmap python3-psycopg2 python3-pip snmp 
sudo apt-get install -y uml-utilities util-linux vlan postgresql wget qemu-system-arm qemu-system-mips qemu-system-x86 qemu-utils vim unzip
sudo ln -s /usr/bin/python3 /usr/bin/python
python3 -m pip install --upgrade pip

# Move to firmadyne dir
FIRMADYNE_INSTALL_DIR=/firmadyne
mkdir $FIRMADYNE_INSTALL_DIR
pushd $FIRMADYNE_INSTALL_DIR

# Clone repos
sudo apt-get install -y nano john
git clone https://github.com/ReFirmLabs/binwalk
git clone --recursive https://github.com/firmadyne/firmadyne.git

# Set up binwalk
pushd binwalk
sudo ./deps.sh --yes
sudo python3 ./setup.py install
popd

# Install additional deps
sudo pip3 install git+https://github.com/ahupp/python-magic
sudo pip3 install git+https://github.com/sviehb/jefferson

# Set up database
sudo service postgresql start
sudo -u postgres createuser firmadyne
sudo -u postgres createdb -O firmadyne firmware
sudo -u postgres psql -d firmware < ./firmadyne/database/schema
echo "ALTER USER firmadyne PASSWORD 'firmadyne'" | sudo -u postgres psql

# Set up firmadyne
pushd firmadyne
./download.sh

# Set FIRMWARE_DIR in firmadyne.config
mv firmadyne.config firmadyne.config.orig
echo -e '#!/bin/sh' "\nFIRMWARE_DIR=$(pwd)/" > firmadyne.config
cat firmadyne.config.orig >> firmadyne.config

# Make sure firmadyne user owns this dir
sudo chown -R firmadyne:firmadyne $FIRMADYNE_INSTALL_DIR
