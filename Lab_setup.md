# IoT Firmware Analysis

### Extract the firmware 
To perform reverse engineering, it is necessary to have access to the firmware. If you are fortunate, you may be able to find the firmware.img on the internet. However, if it is not available, you will need to access the hardware and physically extract the firmware. Some boards have UART pins that can be used in conjunction with a USB-UART interface to access the system.

If you require more information, you can refer to the following link: https://github.com/Numb3rsProprety/Reverse-Engineering-Tenda-CP3.

For instance, to learn how to open the device and locate the Rx/Tx pins, you can refer to the provided images for guidance.

<p float="left">
<img src="https://github.com/sami2316/firmadyne/blob/master/img/IMG_4038.png" width="250" height="300">
<img src="https://github.com/sami2316/firmadyne/blob/master/img/IMG_4039.png" width="250" height="300">
<img src="https://github.com/sami2316/firmadyne/blob/master/img/IMG_4040.png" width="250" height="300">
<img src="https://github.com/sami2316/firmadyne/blob/master/img/IMG_4041.png" width="250" height="300">
<img src="https://github.com/sami2316/firmadyne/blob/master/img/IMG_4042.png" width="250" height="300">
</p>

### Firmware Emulation
1. Build the Docker machine. Docker machine is based on Firmadyne tool, which will be used for emulation of extracted hardware and any static or dynamic analysis. Run the following command in terminal. 
```
    docker build -t firmadyne .
```

2. Run the docker container using the following command. 
   
   ```
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
   
3. In this lab, we will be using the following firmware. 
```
    $ wget -N --continue https://down.tenda.com.cn/uploadfile/CP3/CP3_2111220956.zip
    $ ZIP_FILE="CP3_2111220956.zip"
```

4. Once you have the firmware, extract and format the `.zip` file. 
```
    $ python3 ./sources/extractor/extractor.py -b Tenda -sql 127.0.0.1 -np -nk "$ZIP_FILE" images
``` 

5. Check the `images` folder and ensure that there is a file `<1>.tar.gz`. Then convert the file to an Linux image, which can be emulated by Firmadyne.
```
    $ sudo -SE ./scripts/makeImage.sh <1>
```
Be sure to fill the above command with the number of `<1>.tar.gz`.

6. Set up the networking and try to infer the network configurations. `inferNetwork.sh` will generate the `run.sh` file, which 
7. has all the instructions/commands to run the the generated image in QEMU. 
```
    $ ./scripts/inferNetwork.sh 1
```

7. Finally execute the `run.sh` to emulate the firmware image (`<1>.tar.gz`)
```
    $ ./scratch/1/run.sh

    (none) login: root
    Password: 

```

#### Task 1: Run all the above steps and emulate the firmware.

The emulation process is complete. But how to analyse the firmware?

## Firmware Analysis
There are various static and dynamic analysis techniques for firmware analysis. We will opt both and our objective is to extract as much information 
possible and get `root` access to the IP camera. 

**Why root access and what information should we looking for?**

#### Static Analysis
For static analysis, we will use `binwalk` tool; also a part of Firmadyne tool. `binwalk` is efficient in analysing the type of binaries. 

1. In the `/work` folder, you have `CP3_2111220956.zip` file, unzip it to extract the firmware image. 
```
    $unzip CP3_2111220956.zip
```

2. The extracted folder will have `Flash.img` file, which is our target firmware. 
3. Run the static analysis on Flash.img using binwalk, which will extract the all the IoT application files into `_Flash.img.extracted`. 
```
    $binwalk -re Flash.img
    $ls
     5432C		squashfs-root
  
```
The `squashfs-root` contain all files of our analysis. Let's dig it deeper. 

4. Explore the s*quashfs-root* folder and analyze the all `.conf` and `.sh` files. 
```
    ls squashfs-root
    abin			db_init.sh		lib			sd_hotplug.sh		usb_dev.sh
    ap_mode.cfg		gpio.sh			mi.sh			sdio_dev.sh		userdata
    app_check_setting.sh	hdt_model		modules			sensor.def		wav
    app_init.sh		idump.sh		modules.sh		shadow			wifi_mode.sh
    app_init_ex.sh		iu.sh			modules_post.sh		start.sh
    bin			iu_s.sh			myinfo.sh		sysinfo
    customize.sh		kill_app.sh		sd_fs.sh		udhcpc.script
```

#### Task 2: Perform manual static analysis and report your findings.
  - Ports
  - IPs
  - Other network configurations like protocols.
  - Passowords
  - Sensor information

When you find the passwords, try them into the emulated firmware terminal. 

5. Did you get lucky in finding the password? Lets explore the `shadow` file. 
```
    cat shadow
    root:7h2yflPlPVV5.:18545:0:99999:7:::
```

The first two parts are significantly improtant i.e. username (root) and password (7h2yflPlPVV5.). So we know the username but the passoword
part is encrypted. How to decrypt the password? 

6. Well `John the Ripper` will save our life and do the cracking job. 
```
    # First unshadow the file, which required "/etc/passwd" file. Unfortunately, this file does not exist here but we can use a general one.
    $ echo "root:x:0:0:root:/root:/bin/sh" > passwd.txt
    $ unshadow passwd.txt shadow ? unshadow.txt
    $ john unshadow.txt
    $ john --show unshadow.txt
```
When `john unshadow.txt` completes its job, then run `john --show unshadow.txt` to show the cracked password. 


#### Task 3: Crack the password, following steps 5 and 6

*Did you get success, there are rare chances. why?* Explore the reason and discuss. 


### Dynamic Analysis
1. Lets mount the emulated image, generated in Task 1. 
```
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


