#!/usr/bin/env bash
#
# This script will ask users about their preferences like disk, file system, timezone, keyboard layout, user name, password, etc.
# @stdout Output routed to startup.log
# @stderror Output routed to startup.log


### BEGIN SCRIPT ###

### General system checks

arch_check() {
    if [[ ! -e /etc/arch-release ]]; then
        echo -ne "ERROR! This script must be run in Arch Linux!\n"
        exit 0
    fi
}

root_check() {
    if [[ "$(id -u)" != "0" ]]; then
        echo -ne "ERROR! This script must be run under the 'root' user!\n"
        exit 0
    fi
}

pacman_check() {
    if [[ -f /var/lib/pacman/db.lck ]]; then
        echo "ERROR! Pacman is blocked."
        echo -ne "If not running remove /var/lib/pacman/db.lck.\n"
        exit 0
    fi
}

background_checks() {
    root_check
    arch_check
    pacman_check
}



### Create setup.conf
CONFIG_FILE=$CONFIGS_DIR/setup.conf
if [ ! -f $CONFIG_FILE ]; then # check if file exists
    touch -f $CONFIG_FILE # create file if not exists
fi


### Create option function for proper handling of variables in setup.conf
# arg $1 string Configuration variable.
# arg $2 string Configuration value.
set_option() {
    if grep -Eq "^${1}.*" $CONFIG_FILE; then # check if option exists
        sed -i -e "/^${1}.*/d" $CONFIG_FILE # delete option if exists
    fi
    echo "${1}=${2}" >>$CONFIG_FILE # add option
}


### Start variable handlers
set_password() {
    read -rs -p "Please enter password: " PASSWORD1
    echo -ne "\n"
    read -rs -p "Please re-enter password: " PASSWORD2
    echo -ne "\n"
    if [[ "$PASSWORD1" == "$PASSWORD2" ]]; then
        set_option "$1" "$PASSWORD1"
    else
        echo -ne "ERROR! Passwords do not match. \n"
        set_password
    fi
}


filesystem () {
read -rs -p "Please enter the desired file system for both boot and root ("btrfs" "ext4" "luks" "exit"): " FS
echo -ne "\n"
case $FS in
0) set_option FS btrfs;;
1) set_option FS ext4;;
2) 
    set_password "LUKS_PASSWORD"
    set_option FS luks
    ;;
3) exit ;;
*) echo "Wrong option please select again"; filesystem;;
esac
}


timezone () {
time_zone="$(curl --fail https://ipapi.co/timezone)"
echo -ne "
System detected your timezone to be '$time_zone' \n"
echo -ne "Is this correct?
" 

case ${options[$?]} in
    y|Y|yes|Yes|YES)
    echo "${time_zone} set as timezone"
    set_option TIMEZONE $time_zone;;
    n|N|no|NO|No)
    echo "Please enter your desired timezone e.g. Europe/London :" 
    read new_timezone
    echo "${new_timezone} set as timezone"
    set_option TIMEZONE $new_timezone;;
    *) echo "Wrong option. Try again";timezone;;
esac
}
# @description Set user's keyboard mapping. 
keymap () {
echo -ne "
Please select key board layout from this list"
# These are default key maps as presented in official arch repo archinstall
options=(us by ca cf cz de dk es et fa fi fr gr hu il it lt lv mk nl no pl ro ru sg ua uk)

select_option $? 4 "${options[@]}"
keymap=${options[$?]}

echo -ne "Your key boards layout: ${keymap} \n"
set_option KEYMAP $keymap
}

# @description Choose whether drive is SSD or not.
drivessd () {
echo -ne "
Is this an ssd? yes/no:
"

options=("Yes" "No")
select_option $? 1 "${options[@]}"

case ${options[$?]} in
    y|Y|yes|Yes|YES)
    set_option MOUNT_OPTIONS "noatime,compress=zstd,ssd,commit=120";;
    n|N|no|NO|No)
    set_option MOUNT_OPTIONS "noatime,compress=zstd,commit=120";;
    *) echo "Wrong option. Try again";drivessd;;
esac
}

# @description Disk selection for drive to be used with installation.
diskpart () {
echo -ne "
------------------------------------------------------------------------
    THIS WILL FORMAT AND DELETE ALL DATA ON THE DISK
    Please make sure you know what you are doing because
    after formating your disk there is no way to get data back
------------------------------------------------------------------------

"

PS3='
Select the disk to install on: '
options=($(lsblk -n --output TYPE,KNAME,SIZE | awk '$1=="disk"{print "/dev/"$2"|"$3}'))

select_option $? 1 "${options[@]}"
disk=${options[$?]%|*}

echo -e "\n${disk%|*} selected \n"
    set_option DISK ${disk%|*}

drivessd
}

# @description Gather username and password to be used for installation. 
userinfo () {
read -p "Please enter your username: " username
set_option USERNAME ${username,,} # convert to lower case as in issue #109 
set_password "PASSWORD"
read -rep "Please enter your hostname: " nameofmachine
set_option NAME_OF_MACHINE $nameofmachine
}

# @description Choose AUR helper. 
aurhelper () {
  # Let the user choose AUR helper from predefined list
  echo -ne "Please enter your desired AUR helper:\n"
  options=(paru yay picaur aura trizen pacaur none)
  select_option $? 4 "${options[@]}"
  aur_helper=${options[$?]}
  set_option AUR_HELPER $aur_helper
}

# @description Choose Desktop Environment
desktopenv () {
  # Let the user choose Desktop Enviroment from predefined list
  echo -ne "Please select your desired Desktop Enviroment:\n"
  options=( `for f in pkg-files/*.txt; do echo "$f" | sed -r "s/.+\/(.+)\..+/\1/;/pkgs/d"; done` )
  select_option $? 4 "${options[@]}"
  desktop_env=${options[$?]}
  set_option DESKTOP_ENV $desktop_env
}

# @description Choose whether to do full or minimal installation. 
installtype () {
  echo -ne "Please select type of installation:\n\n
  Full install: Installs full featured desktop enviroment, with added apps and themes needed for everyday use\n
  Minimal Install: Installs only apps few selected apps to get you started\n"
  options=(FULL MINIMAL)
  select_option $? 4 "${options[@]}"
  install_type=${options[$?]}
  set_option INSTALL_TYPE $install_type
}

# More features in future
# language (){}

# Starting functions
background_checks
clear
logo
userinfo
clear
logo
desktopenv
# Set fixed options that installation uses if user choses server installation
set_option INSTALL_TYPE MINIMAL
set_option AUR_HELPER NONE
if [[ ! $desktop_env == server ]]; then
  clear
  logo
  aurhelper
  clear
  logo
  installtype
fi
clear
logo
diskpart
clear
logo
filesystem
clear
logo
timezone
clear
logo
keymap
