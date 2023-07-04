# pi-gadget-mode

This doc describes how to activate RPI4's USB-C gadget mode with some scripts.

<br/>

## Prerequisite

Please find and flash the Raspbian OS Lite image to a micro SD card.
- https://www.raspberrypi.com/software/operating-systems/#raspberry-pi-os-64-bit
- Bullseye (or newer)

<br/>

## 0. Flash OS image to SD card

Flash the zip file to SD card ($TARGET can be /dev/sda, /dev/sdb, or /dev/sdc):
```sh
$ xzcat 2023-05-03-raspios-bullseye-arm64-lite.img.xz| \
	sudo dd of=$TARGET bs=8M oflag=dsync status=progress
```

Then mount the newly created partitions (the paths might be /media/$USER/bootfs and roots).

<br/>

## 1. In the SD card

### 1.1 Booting params

Add these lines to the **/media/$USER/bootfs/config.txt**:
```
dtoverlay=dwc2
enable_uart=1
```

Create a file to activate ssh:
```sh
$ touch /media/$USER/bootfs/ssh
```

<br/>

### 1.2 WIFI setup for Raspbian OS

Create a file to activate WIFI:
```sh
$ touch /media/$USER/bootfs/wpa_supplicant.conf
```

The content should be:
- The AP-NAME and AP-PASSWORD should be surrounded by double quotes.
```
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
ap_scan=1
fast_reauth=1
country=US

network={
	ssid="$AP-NAME"
	psk="$AP-PASSWORD"
	id_str="0"
	priority=100
}
```

<br/>

### 1.3 Remove the security warning

There was a new security rule to create a new user other than pi during 2022. To avoid:
```sh
$ sudo rm /media/$USER/rootfs/etc/ssh/sshd_config.d/rename_user.conf
```

Then unmount the card.

<br/>

## 2. Access to RPI4

Boot the rpi with the card and access via serial console or ssh.

Also, the default ID/PW is: 
- pi
- raspberry
<br/>

### 2.1 Option 1 - serial console

Use these commmands if USB to serial cable is available:

```sh
$ sudo apt install minicom
$ sudo minicom -b 115200 -o -D /dev/ttyUSB0
```

The hardware flow control (of minicom) should be disabled.

<br/>

### 2.2 Option 2 - ssh 

Use this command if WIFI is available:
```
$ ssh pi@raspberrypi.local
```

If the hostname doesn't work:
```
$ sudo apt install nmap
$ hostname -I
$ nmap -sP 192.168.x.0/24 # if the hostname command returned 192.168.x.x
```

<br/>

## 3. Raspi-config

To configure the rpi4 via the terminal (this only works for Raspbian OS):
```
$ sudo raspi-config

# Change the password
# Set the host name
# Enable sshd
```

<br/>

## 4. Secure shell daemon configuration

Edit /etc/ssh/sshd_config:
- Change the sshd to have a certain port number  
- Change ClientAliveInterval to 120
- Change ClientAliveCountMax to 720

<br/>

## 5. Install basic packages

Install some packages first:
```
$ sudo apt install vim git neofetch dnsmasq
```

<br/>

## 6. Configurations for kernel module and network

Add this to the **/boot/cmdline.txt**:
```
modules-load=dwc2,g_ether
```

Add this to the **/etc/modules**:
```
libcomposite
```

Add this to the **/etc/dhcpcd.conf**:
```
denyinterfaces usb0
```

<br/>

## 7. Dnsmasq configuration

Dnsmasq works as a DHCP server and it will only assign IP addresses to the USB-attached devices (the host PC in our case).

Create a new file:
```sh
$ sudo touch /etc/dnsmasq.d/usb
```

Add these to the file:
```
interface=usb0
dhcp-range=10.55.0.2,10.55.0.6,255.255.255.248,1h
dhcp-option=3
leasefile-ro
```

<br/>

## 8. Fixed ip address for USB0

With these config, the USB port will have the fixed IP address.

Create a new file:
```sh
$ sudo touch /etc/network/interfaces.d/usb0 
```

Add this to the file:
```
auto usb0
allow-hotplug usb0
iface usb0 inet static
  address 10.55.0.1
  netmask 255.255.255.248
```

<br/>

## 9. Reboot RPI

The basic settings are done!

Please connect the RPI4 to the host PC via USB cable, so that it reboots and the USB port can be used as ethernet.

<br/>

## 10. Access to RPI with the fixed address

Try these commands:

```sh
$ ping 10.55.0.1
$ nmap 10.55.0.1
```

<br/>

