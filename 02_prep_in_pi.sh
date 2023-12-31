#!/bin/bash

set -e

CPU_TYPE=$(uname -m)

if [[ "$EUID" == 0 ]];
    then echo "Please run as normal user (w/o sudo)"
    exit
fi

term_color_red () {
    echo -e "\e[91m"
}

term_color_white () {
    echo -e "\e[39m"
}

check_architecture(){
    if [[ ! $CPU_TYPE == "aarch64" ]]; then
        echo "Architecture $CPU_TYPE is not aarch64"
        exit
    fi

    if [[ ! -f "/usr/bin/raspi-config" ]]; then
        echo "Cannot find the raspi-config binary"
        exit
    fi
}

confirmation(){
    term_color_red
    echo "Do you want to proceed? (y/n)"
    term_color_white

    echo
    read -n 1 ans
    echo

    if [[ ! $ans == "y" ]]; then
        echo ""
        exit -1
    fi
}

prep(){
    term_color_red
    echo "Prep"
    term_color_white

    # Install some packages
    sudo apt install -y \
        vim git dnsmasq

    # Add params to load kernel modules at boot time by bootloader
    CMDLINE=$(cat /boot/cmdline.txt)
    CMD_EXISTS=$(echo $CMDLINE | grep dwc2 | wc -l)
    if [[ $CMD_EXISTS == "0" ]]; then
        #sudo bash -c "echo ${CMDLINE}' modules-load=dwc2,g_ether' > /boot/cmdline.txt"
        sudo sed -i 's/rootwait/modules-load=dwc2,g_ether rootwait/g' /boot/cmdline.txt
    fi

    # Add a line to load kernel modules at boot time by kernel
    MODULES_EXISTS=$(echo /etc/modules | grep libcomposite | wc -l)
    if [[ $MODULES_EXISTS == "0" ]]; then
        sudo bash -c "echo 'libcomposite' >> /etc/modules"
    fi

    # Add a line to prevent USB0 being configured for network by non-dnsmasq
    DENY_EXISTS=$(echo /etc/dhcpcd.conf | grep debyinterfaces | wc -l)
    if [[ $DENY_EXISTS == "0" ]]; then
        sudo bash -c "echo '' >> /etc/dhcpcd.conf"
        sudo bash -c "echo 'denyinterfaces usb0' >> /etc/dhcpcd.conf"
    fi

    # Configure dnsmasq
    sudo touch /etc/dnsmasq.d/usb
    sudo bash -c "echo -e '
interface=usb0
dhcp-range=10.55.0.2,10.55.0.6,255.255.255.248,1h
dhcp-option=3,192.168.1.1
dhcp-option=6,8.8.8.8
leasefile-ro' >> /etc/dnsmasq.d/usb"

    # For fixed IP addresses
    sudo touch /etc/network/interfaces.d/usb0
    sudo bash -c "echo -e '
auto usb0
allow-hotplug usb0
iface usb0 inet static
    address 10.55.0.1
    netmask 255.255.255.248
    gateway 192.168.1.1
    dns-nameservers 8.8.8.8' >> /etc/network/interfaces.d/usb0"
}

post(){
    term_color_red
    echo "Done"
    echo "Reboot and check if USB-ethernet works"
    term_color_white
}

trap term_color_white EXIT
check_architecture
confirmation
prep
post
