# pi-gadget-mode

This doc describes how to activate RPI4's USB-C gadget mode.

<br/><br/>

## Reference

- https://www.hardill.me.uk/wordpress/2019/11/02/pi4-usb-c-gadget/
- https://support.speedify.com/article/576-turning-a-raspberry-pi-into-a-speedify-usb-gadget
- https://learn.adafruit.com/turning-your-raspberry-pi-zero-into-a-usb-gadget/ethernet-gadget
- https://www.thepolyglotdeveloper.com/2016/06/connect-raspberry-pi-zero-usb-cable-ssh/
- https://www.raspberrypi.org/documentation/hardware/raspberrypi/booteeprom.md
- https://www.ssh.com/ssh/copy-id

<br/><br/>

## Prerequisite

Please find and flash the Raspbian OS image to a micro SD card.
- https://www.raspberrypi.org/downloads/raspbian/
- Buster (or newer)

<br/><br/>

## 0. Flash OS image to SD card

Flash the zip file to SD card:
```sh
$ unzip -p raspbian.zip raspbian.img | dd of=/dev/sdb bs=1M
```

<br/><br/>

## 1. In the SD card

Add these lines to the **/boot/config.txt**:

```
dtoverlay=dwc2
enable_uart=1
```

Create a file to activate ssh:

```
touch /boot/ssh
```

<br/><br/>

### 1.2 WIFI setup for Raspbian OS

Create a file to activate WIFI:

```
touch /boot/wpa_supplicant.conf
```

The content should be:

```
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
ap_scan=1
fast_reauth=1
country=US

network={
	ssid="AP-NAME"
	psk="AP-PASSWORD"
	id_str="0"
	priority=100
}
```

<br/><br/>

## 2. Access to RPI4

Boot the rpi with the card and use one of below options.
<br/><br/>

### 2.1 Option 1: serial console

Use this commmand if USB to serial cable is available:

```sh
$ sudo apt install minicom
$ sudo minicom -b 115200 -o -D /dev/ttyUSB0
```

The hardware flow control (of minicom) should be disabled.

<br/><br/>

### 2.2 Option 2: ssh 

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

The default password is **raspberry**.

<br/><br/>

### 2.3 Boot from SSD 

As of today (March 2020), RPI4 doesn't support booting from USB.  
However, some tweak can change to use root (/) directory of external SSD.
- https://jamesachambers.com/raspberry-pi-4-usb-boot-config-guide-for-ssd-flash-drives/

Currently, these devices are being used:
- Orico's USB-C to SATA3 enclosure (this uses VIA Lab chipset inside)
- WD Green SSD 128GB

The steps are simple:
- Burn Raspbian Buster for both SD card and SSD
- Create the **ssh** and **wpa_cupplicant.conf** for SD card's boot partition as above
- Boot RPI with SD card only
- After boot, access RPI4 via SSH or serial console (but don't do update or config anything)
- Attach SSD and check USB ID of SSD with **lsusb** command
- Add **usb-storage.quirks=2109:0715:u** to /boot/cmdline.txt of SD card
- Do these for SSD to change disk identifier
  - sudo fdisk /dev/sda
  - p (to see the existing partitions)
  - x (to enter the expert mode)
  - i (to change disk identifier)
  - 0xd34db33f (new disk identifier)
  - r (to leave the expert mode)
  - w (to write changes)
- New disk identifier change be checked by **sudo blkid**
- Edit /boot/cmdline.txt of SD card
  - from root=PARTUUID=**6c586e13-02**
  - to root=PARTUUID=**d34db33f-02**
- Update /etc/fstab
  - from PARTUUID=**6c586e13-02**
  - to PARTUUID=**d34db33f-02**
- Create the **ssh** and **wpa_cupplicant.conf** for SD card's boot partition as above (Yes, **AGAIN**)
- Add **dtoverlay=dwc2** to /boot/config.txt (**AGAIN**)
- Reboot
- Try **findmnt -n -o SOURCE /**
- Do these for SSD to resize disk size
  - sudo fdisk /dev/sda (please remember the first sector of sda2. mostlikely, it is 532480)
  - p (to see the existing partitions)
  - d (to delete partition)
  - 2 (to specify partition sda2)
  - n (to create new partition)
  - p (to specify primary partition)
  - 2 (to specify partition sda2)
  - 532480 (to set the first sector)
  - enter (to set the last sector)
  - n (for "do you want to remove the signature?")
  - w (to write changes)
- reboot
- df -h (at this time the size is same as before)
- sudo resize2fs /dev/sda2
- df -h (now the size is as configured)

Now SSD is the root disk with its max size.

<br/><br/>

## 3. Raspi-config

To configure the rpi4 via the terminal (this only works for Raspbian OS):

```
$ sudo raspi-config
```

- Change the password
- Set the host name to be pipi4b
- Enable the sshd

<br/><br/>

## 4. Secure shell daemon configuration

Edit /etc/ssh/sshd_config:

- Change the sshd to have port number  
- Change ClientAliveInterval 120
- Change ClientAliveCountMax 720

<br/><br/>

## 5. Install basic packages

Install some packages first:

```
$ sudo apt install vim git neofetch dnsmasq
```

<br/><br/>

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

<br/><br/>

## 7. Dnsmasq configuration

Dnsmasq works as a DHCP server and it will only assign IP addresses to the USB-attached devices (the host PC in our case).

Create a new file:

```
$ sudo touch /etc/dnsmasq.d/usb
```

Add this to the file:

```
interface=usb0
dhcp-range=10.55.0.2,10.55.0.6,255.255.255.248,1h
dhcp-option=3
leasefile-ro
```

<br/><br/>

## 8. Fixed ip address for USB0

With these config, the USB port will have the fixed IP address.

Create a new file:

```
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

<br/><br/>

## 9. Reboot RPI

The basic settings are done!  
Please reboot and the USB port can be used as ethernet so that connect the RPI4 to the host via USB-C.

<br/><br/>

## 10. Access to RPI with the fixed address

Try these commands:

```sh
$ ping 10.55.0.1
$ nmap 10.55.0.1
```

<br/><br/>

## 11. No password login

To enable the no password login, follow these steps **from the host**:

```sh
$ ssh-keygen -t rsa -b 2048 -v # file name should be test but no phrase
$ ssh-copy-id -i .ssh/test.pub pi@10.55.0.1 -p 2222 
$ ssh -p 2222 pi@10.55.0.1

# If the key is not established, the ownership might be the matter
$ chmod 600 test
$ chmod 644 test.pub
```

Some tips
- The keygen command might ask a phrase but don't have to put anything. 
- The copy id should be done for every client.
- If ever logged in before this step with ssh, please delete the latest line in the **.ssh/known_hosts** to remove a key. That is because there will be multiple ssh keys.

<br/><br/>

## Conclusion

With the steps, the rpi can be powered and accessed with only 1 USB cable. This reduces the compexity of the connection so that the space can be much more productive!
