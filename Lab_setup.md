# IoT Firmware Analysis

### Extract the firmware 
To perform reverse engineering, it is necessary to have access to the firmware. If you are fortunate, you may be able to find the *firmware image* on the vendor website. However, if it is not available, you must have to access the hardware and physically extract the firmware. Some boards have UART pins that can be used in conjunction with a USB-UART interface to access the system and extract the firmware. A firmware extraction toolchain is available here: https://github.com/TSELab/IoT-Device-Hacking, which can used via UART interface.

In this lab, we have experimented with Tenda CP3 IP camera. For more details to interface UART with CP3 IP camera, you can refer to the following link: https://github.com/Numb3rsProprety/Reverse-Engineering-Tenda-CP3. Moreover, to learn how to open the device and locate the Rx/Tx pins, you can refer to the provided images for guidance (which captured during our in-house efforts).

<p float="left">
<img src="https://github.com/sami2316/firmadyne/blob/master/img/IMG_4038.png" width="250" height="300">
<img src="https://github.com/sami2316/firmadyne/blob/master/img/IMG_4039.png" width="250" height="300">
<img src="https://github.com/sami2316/firmadyne/blob/master/img/IMG_4040.png" width="250" height="300">
<img src="https://github.com/sami2316/firmadyne/blob/master/img/IMG_4041.png" width="250" height="300">
<img src="https://github.com/sami2316/firmadyne/blob/master/img/IMG_4042.png" width="250" height="300">
</p>

## Firmware Analysis
There are various static and dynamic analysis techniques for firmware analysis. We will opt both and our objective is to extract as much information 
possible and get `root` access to the IP camera. 

**Why root access and what information should we looking for?**

#### Static Analysis
For static analysis, we will use `binwalk` tool; also a part of Firmadyne tool. `Binwalk` is very efficient in analysing any type of binary and then extracting the filesystem. 

1. In the `/work` folder, download `CP3_2111220956.zip` file, and unzip it to further explore the firmware image. 
```console
    $ wget -N --continue https://down.tenda.com.cn/uploadfile/CP3/CP3_2111220956.zip
    $ unzip CP3_2111220956.zip
```

2. The unzipped folder will have `Flash.img` file, which is our target firmware; for further analysis. 
3. Run the static analysis on *Flash.img* using *binwalk*, which will extract all firmware files into `_Flash.img.extracted`. 
```console
    $binwalk -re Flash.img
    DECIMAL       HEXADECIMAL     DESCRIPTION
    --------------------------------------------------------------------------------
    202612        0x31774         SHA256 hash constants, little endian
    265936        0x40ED0         CRC32 polynomial table, little endian
    327680        0x50000         uImage header, header size: 64 bytes, header CRC: 0x60386B7B, created: 2021-09-07 08:49:48, image size: 2816144 bytes,                Data Address: 0xA0008000, Entry Point: 0xA0008000, data CRC: 0xEEDEAF3A, OS: Linux, CPU: ARM, image type: OS Kernel Image, compression type: none, image name: "Linux-3.0.8"
    327744        0x50040         Linux kernel ARM boot executable zImage (little-endian)
    344876        0x5432C         gzip compressed data, maximum compression, from Unix, last modified: 1970-01-01 00:00:00 (null date)
    3473408       0x350000        JFFS2 filesystem, little endian

    WARNING: Symlink points outside of the extraction directory: /work/test/_Flash.img.extracted/squashfs-root/abin/ipc_def.db ->   /app/userdata/ipc_def.db; changing link target to /dev/null for security purposes.

    WARNING: Symlink points outside of the extraction directory: /work/test/_Flash.img.extracted/squashfs-root/abin/sensor.bin -> /app/userdata/sensor.bin; changing link target to /dev/null for security purposes.

    WARNING: Symlink points outside of the extraction directory: /work/test/_Flash.img.extracted/squashfs-root/lib/libsensor.so -> /app/userdata/libsensor.so; changing link target to /dev/null for security purposes.

    WARNING: Symlink points outside of the extraction directory: /work/test/_Flash.img.extracted/squashfs-root/sysinfo/hw_info -> /app/userdata/hw_info; changing link target to /dev/null for security purposes.
    3997696       0x3D0000        Squashfs filesystem, little endian, version 4.0, compression:gzip, size: 4073085 bytes, 123 inodes, blocksize: 131072 bytes, created: 2021-11-22 01:57:24
```
```console
    $ls _Flash.img.extracted/
     5432C  jffs2-root  squashfs-root
  
```
The `squashfs-root` contain all files of our analysis. Let's dig it deeper. 

4. Explore the *squashfs-root* folder and analyze all `.conf` and `.sh` files. 
```console
    ls squashfs-root
    abin			db_init.sh		lib			sd_hotplug.sh		usb_dev.sh
    ap_mode.cfg		gpio.sh			mi.sh			sdio_dev.sh		userdata
    app_check_setting.sh	hdt_model		modules			sensor.def		wav
    app_init.sh		idump.sh		modules.sh		shadow			wifi_mode.sh
    app_init_ex.sh		iu.sh			modules_post.sh		start.sh
    bin			iu_s.sh			myinfo.sh		sysinfo
    customize.sh		kill_app.sh		sd_fs.sh		udhcpc.script
```

#### Task 1: Perform manual static analysis and report your findings.
  - Ports
  - IPs
  - Other network configurations like protocols.
  - Passowords
  - Sensor information

When you find the passwords, try them into the emulated firmware terminal. 

5. Did you get lucky in finding the password? Lets explore the `shadow` file. 
```console
    cat shadow
    root:7h2yflPlPVV5.:18545:0:99999:7:::
```

The first two parts are significantly improtant i.e. username (root) and password (7h2yflPlPVV5.). So we know the username but the passoword
part is encrypted. How to decrypt the password? 

6. Well `John the Ripper` will save our life and do the cracking job. 
```console
    # First unshadow the file, which required "/etc/passwd" file. Unfortunately, this file does not exist here but we can use a general one.
    $ echo "root:x:0:0:root:/root:/bin/sh" > passwd.txt
    $ unshadow passwd.txt shadow ? unshadow.txt
    $ john unshadow.txt
    $ john --show unshadow.txt
```
When `john unshadow.txt` completes its job, then run `john --show unshadow.txt` to show the cracked password. 


#### Task 2: Crack the password, following steps 5 and 6

*Did you get success, there are rare chances. why?* Explore the reason and discuss. 


## Firmware Emulation
When we don't have access to the IoT device, we can emulate it and run any dynamic analysis. *Firmadyne* is such a tool and can emulates many IoT devices, provided we have a sample firmware. Carefully follow the steps below to emulate a firmware image using firmadyne. 

1. Run the following command to build a Docker machine that will install all dependencies and Firmadyne tool. We will use this docker container for the emulation of target IoT device and for any static or dynamic analysis. 
```console
    docker build -t firmadyne .
```

2. Run the docker container using the following command. 
   
   ```console
       docker run --privileged --rm -v $PWD:/work -w /work -it --net=host firmadyne
       
       + export PGPASSWORD=firmadyne
       + PGPASSWORD=firmadyne
       + export USER=firmadyne
       + USER=firmadyne
       + echo firmadyne
       + sudo -S service postgresql start
       [sudo] password for firmadyne:  * Starting PostgreSQL 9.3 database server                                                  [ OK ] 
       + echo 'Waiting for DB to start...'
       Waiting for DB to start...
       + sleep 5
       + exec /bin/bash
   ```
   
3. In this lab, we will be using the following firmware (Tenda CP3 IP camera). 
```console
    $ wget -N --continue https://down.tenda.com.cn/uploadfile/CP3/CP3_2111220956.zip
    $ ZIP_FILE="CP3_2111220956.zip"
    $ mkdir test
    $ unzip $ZIP_FILE -d test
    $ binwalk -re test/Flash.img
    
```

4. Once you have the firmware, then extract it and format the `.zip` file. The `firmadyne` linked (dependency) `extractor.py` has some limitations and not extracting the squashfs-root filesystem into the *tar.gz*. To deal with this limitation, we need to manually copy the squashfs-root files into the target tar file. 
```console
    $ cd /work
    $ python3 ./sources/extractor/extractor.py -b Tenda -sql 127.0.0.1 -np -nk "$ZIP_FILE" images
    $ unzip /work/images/<1>.tar.gz
    $ tar --append --file=images/<1>.tar -C test/_Flash.img.extracted/squashfs-root/ .
    $ gzip /work/images/<1>.tar
``` 

5. Check the `images` folder and ensure that there is a file `<1>.tar.gz`. Then convert the file to an Linux image, which can be emulated by Firmadyne.
```console
    $ sudo -SE ./scripts/makeImage.sh <1>
```
Be sure to fill the above command with the number of `<1>.tar.gz`.

6. Set up the networking and try to infer the network configurations. `inferNetwork.sh` will generate the `run.sh` file, which 
7. has all the instructions/commands to run the the generated image in QEMU. 
```console
    $ ./scripts/inferNetwork.sh 1
```

7. Finally execute the `run.sh` to emulate the firmware image (`<1>.tar.gz`)
```console
    $ ./scratch/1/run.sh

    (none) login: root
    Password: 

```

#### Task 3: Run all the above steps and emulate the firmware.

The emulation process is complete and we have access to the terminal but we don't know the username and password. How to dynamically analyse the firmware? 
Well, we can mount the image as Linux filesystem using the script privided in Firmadyne directory. 

### Dynamic Analysis
1. Lets mount the emulated image, generated in Task 3. 
```console
    $ sudo su
    # export FIRMWARE_DIR='.'
    # ./scripts/mount.sh 3
    
    ----Running----
    ----Adding Device File----
    ----Mounting /dev/mapper/loop0p1----
    ----Mounted at ./scratch//3//image/----
```

2. Once mounted, goto `cd scratch/3/image` and analyze the emulated image. 

#### Task 4: Anlyse mounted directory and explore it. 
  - Observe the differences compared to binwalk extracted one and mounted one.
  - Repeat Task 3 for the mounted directory.
  - You will observe a different content in `shadow` file. 
  - Use /etc/shadow and /etc/passwd to prepare unshadow.txt and run `john` over it. 
  - Try the cracked password in emulated shell.
  - Explore the terminal access to emulated firmware and explore the system.

* Well you have got the root access; Hack done, the rest is penetration is as per your imagination. 

## Reverse Engineering the Functionality of App?
In your previous static analysis, you might have observed many binaries file, which seems specific to the IoT device functionality e.g. the ones in `abin`, `hdt_model`, etc. In previous system security course, we have done extensive reverse engineering exercises using `radare2` tool but in this lab, we use Ghidra, which is opensource, have better GUI, and improved analysis experience for bigger binaries.

1. Install Ghidra.
```console
    $ git clone https://github.com/bkerler/ghidra_installer
    $ cd ghidra_installer
    $ ./install-ghidra.sh
```

2. Run Ghidra
```console
    $ ghidra
```

### DEMO for using Ghidra
#### Task 5: Anlyse ARM files in `modules` directory 
- Import `enc.ko` file and make a Ghidra project
- Analyse the file and report the encryption algorithm used and its working. 
- Choose anyother file from `modules` directory and report any interesting findings. 

**Congratulations, you've taken your first step toward IoT firmware analysis.**
