#!/bin/bash

# How to run:
#    $ docker run --privileged --rm -v $PWD:/work -w /work -it --net=host firmadyne
#    $ /work/example_analysis.sh

set -e
set -x

# Download firmware image
pushd /firmadyne/firmadyne
wget -N --continue https://down.tenda.com.cn/uploadfile/CP3/CP3_2111220956.zip
ZIP_FILE="CP3_2111220956.zip"

# Download all arch kernal images
./download.sh

mkdir test
unzip $ZIP_FILE -d test
binwalk -re test/Flash.img

python3 ./sources/extractor/extractor.py -b Tenda -sql 127.0.0.1 -np -nk "$ZIP_FILE" images
gunzip images/1.tar.gz
tar --append --file=images/1.tar -C test/_Flash.img.extracted/squashfs-root/ .
gzip images/1.tar

./scripts/getArch.sh ./images/1.tar.gz
./scripts/tar2db.py -i 1 -f ./images/1.tar.gz

# FIXME: Why does the following command return error status?
set +e
echo "firmadyne" | sudo -SE ./scripts/makeImage.sh 1
set -e

echo "Detecting network configuration"
./scripts/inferNetwork.sh 1

echo "Booting..."
./scratch/1/run.sh
