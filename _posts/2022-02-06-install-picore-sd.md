---
title: Install piCore on a RasPi 4 to SD card
categories: piCore RasPi
tags: install
excerpt: Brief installation guide for piCore on Raspberry PI.
---

# {{ page.title }}

This should be a complete list of commands that I used to setup piCore on my Pi 4B using a SD-card.

## Disclaimer

It might help you to utilize piCore on your machine. And the Pi specific stuff can be easily adjusted to other target machines.

I won't get in details about how piCore works but I list some resources in the [Appendix](#appendix). Also networking is not covered as my machines are cable connected and can find each other automagically.

lot's of commands shown use _sudo_ to execute with elevated permissions.

Be vigilant about your settings - especially disks and partitions.

Blindly copy and paste that stuff may brake and even destroy your running system.

## Definitions

All machines are in the same *wired* network and are served with DNS/DHCP. piCore detects all at boot time so network works OOTB for me.

* **Pi** - this is my Raspi 4B
* **box** - the standard hostname applied by piCore to the PI
* **tc** - the standard piCore user with _sudo_ access
* **host** - my full featured Desktop machine where I prepare everything. [Manjaro Minimal (XFCE)]. If you miss a command I use, you might need to install manually. (I don't remember which I installed manually before.)
* **rik** - user with _sudo_ access on _host_

## Introduction

There's is no installer for piCore 13.1 but the image will fire smoothly.

Release notes on the welcome page only state version 12.0. There's some stuff available for a 13.1 version. Checking the ports page http://www.tinycorelinux.net/ports.html there are two links

* _Raspberry Pi Headline_ will send you to an arm6 12.x version
* _Stable releases_ will send you to an arm6 13.x version

Manually browsing the repo you can find some more folders like armv7l and aarch64. but as they are not officially exposed I will not use them.

I will start with the piCore 13.1.0 version from http://tinycorelinux.net/13.x/armv6/releases/RPi/ which you can reach when selecting the _Stable Release_ link on the ports page.

## Persistance vs Backup

The setup uses just one SD-Card for everything, so in fact there's no real backup of anything. You will use loose all your data if the SD card gets corrupted.

All options on persistance are there to keep changes between reboots.

So regardless of any of this options you would want to:

* backup your SD-Card to an external drive or other SD
* use a usb stick/drive for the persistent data
** ofc also backing that up

## Prerequisites

* Raspi Model 4B (others may work, too)
  * display and keyboard connected (depending on the variant used below)
* SD card
* A machine to download, burn, and modify the SD-Card.
  * mine is a Manjaro Linux minimal (XFCE) Desktop

## SD-Card preparation

This will be done on the Host.

There are plenty of guides for that. So just brief here.

* download and unzip piCore
  * http://tinycorelinux.net/13.x/armv6/releases/RPi/piCore-13.1.0.zip
* burn to the SD-Card
  * I use `raspi-imager`. Easy to use and does the job.

We now could fire up the raspi using the SD-Card, but let's tweak it a little bit before.

### Resize Data Partition

Over the time you might want to install additional software, store large files in your home, play around... but there is not much space currently.

After burning the USB Stick you will have two partitions on your stick.

* Partition 1 - Label piCore-13

  This holds the Raspi boot files, the linux kernel and the initial root filesystem and has 64 MB. Also Raspi `config.txt` is located here.

* Partition 2 - Label piCore_TCE

  This is the data partition where piCore stores initial config, backup files, and optional components not contained in the core filesystem.

After burning the SD-card, this second Partition is currently only 16 MB in size. The rest of the stick is free Space.

This is the Partition we need to resize to get more space for data and applications. There are plenty of guides around how to resize a partition so I won't go in detail but list a brief example using `gparted`. The easy one shot option, resizing partition and filesystem.

* check filesystem for errors
  ```bash
  sudo fsck /dev/sda2
  ## fsck from util-linux 2.37.2
  ## e2fsck 1.46.4 (18-Aug-2021)
  ## piCore_TCE: clean, 23/4096 files, 2570/4096 blocks
  ```

* Resize partition and filesystem
  * start gparted
  * select the USB stick
  * on sda2 use Right Mouse Button -> Resize/Move and enter value for new size
  * press [Resize/Move]
  * press [Apply]

* recheck filesystem for errors
  ```bash
   sudo fsck /dev/sda2
   ## fsck from util-linux 2.37.2
   ## e2fsck 1.46.4 (18-Aug-2021)
   ## piCore_TCE: clean, 24/1933312 files, 63915/15465216 blocks
  ```

### TCE Persistence

Persistence option is set as a kernel boot parameter specifying the type of persistance and the destination partition `tce=PARTITION`. I will use the UUID style.

On my host the stick is available as /dev/sda and it will be different on the SD card. So I need the _UUID_ of partition Two (`/dev/sda2`).

```bash
blkid /dev/sda2
## /dev/sda2: LABEL="piCore_TCE" UUID="*a36eaf4a-7bdc-4836-83cd-8001db75865a*" BLOCK_SIZE="4096" TYPE="ext4" PARTUUID="e85b7916-02"
```

Now edit the file `cmdline.txt` on partition One (`/dev/sda1`) and append the persistence option using the determined _UUID_.

```bash
sudo mount /dev/sda1 /mnt
cat /mnt/cmdline.txt
## zswap.compressor=lz4 zswap.zpool=z3fold console=tty1 root=/dev/ram0 elevator=deadline rootwait quiet nortc loglevel=3 noembed
sudo sed -i '1 s/$/ tce=UUID=a36eaf4a-7bdc-4836-83cd-8001db75865a/' /mnt/cmdline.txt
cat /mnt/cmdline.txt
## zswap.compressor=lz4 zswap.zpool=z3fold console=tty1 root=/dev/ram0 elevator=deadline rootwait quiet nortc loglevel=3 noembed tce=UUID=a36eaf4a-7bdc-4836-83cd-8001db75865a
sudo umount /mnt
```

### Change keyboard layout

I have a german keyboard, so I want to use that layout automatically.

The TiniCore tcz folder (http://tinycorelinux.net/13.x/armv6/tcz/) is not browseable via HTTP, so you need to know the filenames. If you shoose a browseable mirror (like http://distro.ibiblio.org/tinycorelinux/13.x/armv6/tcz/) you can download the files easily using a browser

We need the _keymaps_ extension and have to:

* download kmap extension
* copy it to /dev/sda2/tce/optional
* enable load at boot time
  * add kernel bootcode

#### Install german keyboard

```bash
curl http://tinycorelinux.net/13.x/armv6/tcz/kmaps.tcz > kmaps.tcz
curl http://tinycorelinux.net/13.x/armv6/tcz/kmaps.tcz.md5.txt > kmaps.tcz.md5.txt
sudo mount /dev/sda2 /mnt
sudo cp kmaps.tcz /mnt/tce/optional
sudo cp kmaps.tcz.md5 /mnt/tce/optional
sudo sh -c 'echo "kmaps.tcz" >> /mnt/tce/onboot.lst'
sudo umount /mnt

sudo mount /dev/sda1 /mnt
sudo sed -i '1 s/$/ kmap=qwertz\/de-latin1-nodeadkeys/' /mnt/cmdline.txt ## <1>
sudo umount /mnt
```

A list of available layouts can be found at mirrors in `kmaps.tcz.list`.

* `/dev/sda2/tce/onboot.lst` should look like that now

  ```
  openssh.tcz
  kmaps.tcz
  ```

* `/dev/sda1/cmdline.txt` should look like that now

  ```
  zswap.compressor=lz4 zswap.zpool=z3fold console=tty1 root=/dev/ram0 elevator=deadline rootwait quiet nortc loglevel=3 noembed tce=UUID=a36eaf4a-7bdc-4836-83cd-8001db75865a kmap=qwertz/de-latin1-nodeadkeys
  ```

### Install SSH

OpenSSH is installed and activated by default. At startup the server will generate SSH host keys. But ofc it will now know your Host users public key and the standard tc user has no password set which disallows ssh logins.

If you have display and keyboard attached you can do the following:

* boot from USB Stick
* wait until the SSH keys are created
* you will be automatically logged in
* set a password
  * weak passwords are rejected for normal users
  * use `sudo passwd tc` to set a weak one if you need

If you can live with that skip the following section

#### Enable SSH login

We cannot set a password from outside, so we enable login less SSH by adding your hosts users SSH key to the authorized keys of our piCore user _tc@box_.

For that we have to tweak `/dev/sda/tce/mydata.tgz` by adding our host users public key to ssh authorized keys.

**Warning**: this will add your hosts users public key to the USB stick. You might not want that if you plan to carry that to different machines or give it away.

But it will also allow SSH connections for your host user to all machines using a copy of this USB stick.

```bash
## just have a clean folder to operate in
mkdir ~rik/mydata
cd ~/mydata
sudo bash ## <1>

mount /dev/sda2 /mnt
sh -c 'gzip -dc /mnt/tce/mydata.tgz | tar -xvpf -'

mkdir home/tc/.ssh
cat  ~rik/.ssh/id_rsa.pub > home/tc/.ssh/authorized_keys
chown -R 1001 home/tc/.ssh ## <2>
chmod 700 home/tc/.ssh
chmod g-s home/tc/.ssh
chmod 600 home/tc/.ssh/authorized_keys

tar -cvp * | gzip -c > ../mydata.tgz
cp ../mydata.tgz /mnt/tce
sudo umount /mnt
exit ## <3>
```

1. all following commands need sudo, so ease up typing
2. 1001 is the user id of the tc user on the box
3. exit the sudo bash

### Ready to Rumble

Now

* safely eject the stick, plug into the pi, and boot up
* wait some seconds for it to come up
* connect to the box as user tc

```
 [rik@host ~]$ ssh tc@box
    ( '>')
   /) TC (\   Core is distributed with ABSOLUTELY NO WARRANTY.
  (/-_--_-\)           www.tinycorelinux.net
 tc@box:~$
```
Voila, now we have a working TcCore environment.

[TIP] : Do not forget to backup future changes using `filetool.sh`.

## Appendix

### References

* TinyCore Linux
  * Homepage:: http://tinycorelinux.net/
  * Forum:: http://forum.tinycorelinux.net/
  * Wiki:: http://wiki.tinycorelinux.net/
  * Download Ports:: http://www.tinycorelinux.net/ports.html
  * Downloads:: http://tinycorelinux.net/13.x/
  * tce extensions:: http://tinycorelinux.net/13.x/armv6/tcz/


* Raspberry PI
  * Documentation:: https://www.raspberrypi.com/documentation/computers/raspberry-pi.html