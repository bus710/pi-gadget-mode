#!/bin/bash

set -e

CPU_TYPE=$(uname -m)
AP_NAME=""
AP_PASSWORD=""

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
    if [[ $CPU_TYPE == "x86_64" ]]; then
        echo
    elif [[ $CPU_TYPE == "aarch64" ]]; then
        echo
    else
        echo "Architecture $CPU_TYPE is not known"
        exit
    fi
}

check_mounted(){
    if [[ ! -d "/media/$USER/bootfs" ]]; then
        echo "bootfs directory is not found"
        exit
    elif [[ ! -d "/media/$USER/rootfs" ]]; then
        echo "rootfs directory is not found"
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

    term_color_red
    echo "Wifi router AP name?"
    term_color_white

    echo
    read AP_NAME
    echo

    term_color_red
    echo "Wifi router AP password?"
    term_color_white

    echo
    read AP_PASSWORD
    echo
}

prep(){
    term_color_red
    echo "Prep"
    term_color_white

    # Add those lines into the config.txt
    CONFIG_EXISTS=$(cat /media/$USER/bootfs/config.txt | grep dtoverlay=dwc2 | wc -l)
    if [[ $CONFIG_EXISTS == "0" ]]; then
        echo "" >> /media/$USER/bootfs/config.txt
        echo "dtoverlay=dwc2" >> /media/$USER/bootfs/config.txt
        echo "enable_uart=1" >> /media/$USER/bootfs/config.txt
    fi

    # Create the ssh file so Rpi can start sshd
    if [[ ! -f "/media/$USER/bootfs/ssh" ]]; then
        touch /media/$USER/bootfs/ssh
    fi

    # Create the wifi config file
    if [[ ! -f "/media/$USER/bootfs/wpa_supplicant.conf" ]]; then
        touch /media/$USER/bootfs/wpa_supplicant.conf

        echo -e \
            "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
ap_scan=1
fast_reauth=1
country=US

network={
    ssid=\"${AP_NAME}\"
    psk=\"${AP_PASSWORD}\"
    id_str=\"0\"
    priority=100
}" >> /media/$USER/bootfs/wpa_supplicant.conf
    fi

    # Remove the rename_user.conf to remove the login banner
    sudo rm /media/$USER/rootfs/etc/ssh/sshd_config.d/rename_user.conf

    # Configure user's password
    sudo rm -rf /media/$USER/bootfs/userconf
    touch /media/$USER/bootfs/userconf
    PW=$(echo 'mypassword' | openssl passwd -6 -stdin)
    echo pi:$PW >> /media/$USER/bootfs/userconf
}

post(){
    term_color_red
    echo "Done"
    echo "Unmount the disk"
    term_color_white
}

trap term_color_white EXIT
check_architecture
check_mounted
confirmation
prep
post
