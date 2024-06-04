---
title: Install Manjaro ARM (minimal) on a RasPi 4 to SD card
categories: ["Manjaro", "RasPi"]
tags: ["install"]
date: "2022-03-20"
excerpt: Brief installation guide for Manjaro minimal on Raspberry PI.
---

# Install Manjaro ARM Minimal on a RasPi 4 to SD card

This should be a complete list of commands that I used to setup piCore on my Pi 4B using a SD-card.

## Disclaimer

It might help you to utilize Manjaro Arm on your machine. And the Pi specific stuff can be easily
adjusted to other target machines.

I won't get in details about how Manjaro ARM works but I list some resources in the
[Appendix](#appendix). Also networking is not covered as my machines are cable connected and can
find each other automagically.

lot's of commands shown use _sudo_ to execute with elevated permissions.

Be vigilant about your settings - especially disks and partitions.

Blindly copy and paste that stuff may brake and even destroy your running system.

## Definitions

All machines are in the same _wired_ network and are served with DNS/DHCP. piCore detects all at
boot time so network works OOTB for me.

-  **Pi** - this is my Raspi 4B
-  **manbox** - chosen at first boot
-  **manja** - Chosen at first boot
-  **host** - my full featured Desktop machine where I prepare everything. [Manjaro Minimal (XFCE)].
   If you miss a command I use, you might need to install manually. (I don't remember which I
   installed manually before.)
-  **rik** - user with _sudo_ access on _host_

## Introduction

First we download the image from the Manjaro Distribution site. This states (2022-03-20) 21.12 but
in fact the image downloaded is 22.02. Guess the web page label is just wrong.

This will be the 64-bit edition, so might not work on older hardware.

## Prerequisites

-  Raspi Model 4B (others may work, too)
   -  display and keyboard connected
-  SD card
-  A machine to download, burn, and modify the SD-Card.
   -  mine is a Manjaro Linux minimal (XFCE) Desktop on a x64 machine.

## SD-Card preparation

This will be done on the Host.

There are plenty of guides for that. So just brief here.

-  download Manjaro Arm minimal from
   -  https://manjaro.org/downloads/arm/raspberry-pi-4/arm8-raspberry-pi-4-minimal/.
-  burn to the SD-Card
   -  I use `raspi-imager`. Easy to use and does the job.

After burning the USB Stick you will have two partitions on your stick.

-  Partition 1 - Label BOOT_MNJRO

   This holds the Raspi boot files, the linux kernel and the initial root filesystem and has 214 MB.
   Also Raspi `config.txt` is located here.

-  Partition 2 - Label ROOT_MNJRO

   This is the root partition where Manjaro will be installed. There's no need to manually resize
   that. The installer will take care later.

## Installation

Plug in the SD to the Pi and fire it up. This will start a Installer basic installer to configure
basic settings

-  Keyboard (choose)
-  User: manja
-  Group: add sudoers
-  Fullname: Manjaro User
-  Password: simple
-  Root Password: complex
-  Timezone: (choose)
-  locale: (choose)
-  hostname: manbox

Now a summary will be displayed and the system will reboot.

On the first boot the ROOT_MNJRO partition will be resized to use all free space on the disk.

### Ready to Rumble

Now just login to the box. You may also directly connect via SSH as this is enabled by default.

### References

-  Manjaro Arm Linux

   -  Homepage:: http://manjaro.org/
   -  Forum:: http://https://forum.manjaro.org/
   -  Wiki:: https://wiki.manjaro.org/index.php/Main_Page/
   -  UserGuide:: https://manjaro.org/support/userguide/
   -  Downloads:: https://manjaro.org/downloads/arm/raspberry-pi-4/arm8-raspberry-pi-4-minimal/

-  Raspberry PI
   -  Documentation:: https://www.raspberrypi.com/documentation/computers/raspberry-pi.html
