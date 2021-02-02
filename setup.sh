# Sets up your Raspberry Pi for use with Pat winlink client and Ardop. (Telnet also works.)
# I've not attempted to get this going with Winmor, as that protocol seems to be phased out or soon to be phased out on most gateways at the time of this writing.
# I've not attempted Pactor due to the cost. I've not attempted VARA. (It's not documented as an option for Pat, and I'm not even sure whether it works/has been ported to *nix.)
# This comes with no warranty, guarantee, or herbal tea. Use at your own risk, but myself or the community will try to help you if you get stuck.
# Backups are always a great idea. Hopefully, if you use your radio Pi portable, you've backed up its SD card (maybe one to take with you as spare, and one to leave at home for recovery).
# Alrigh, alright, here we go...
 
echo 'Updating package repository...';
sudo apt update; 
#echo 'Upgrading packages. You may skip this by selecting N.';
#sudo apt upgrade; # You can select No here, if you're worried that upgrades might break something, or you don't think you have time.
#Really, I think any packages that need to get upgraded for this will get upgraded as we install it.

echo;
echo 'Moving files around';
mkdir -p ${HOME}/bin;
cp ./run_pat.sh ${HOME}/bin/run_pat.sh
chmod u+x ${HOME}/bin/run_pat.sh;
cp ./runpat.desktop ${HOME}/Desktop/runpat.desktop
chmod u+x ./gps_time_setup.sh

read -p 'Enter your callsign: ' callsign;

echo;
echo 'Installing hamlib (rigctl)';
if [ -f "/usr/local/bin/rigctl" ]; then
   echo 'hamlib installed';
else
    # pull down hamlib 4.0 for the IC-705
    wget https://sourceforge.net/projects/hamlib/files/hamlib/4.0/hamlib-4.0.tar.gz
    tar -xzf hamlib-4.0.tar.gz
    cd hamlib-4.0
    ./configure
    make
    sudo make install
    sudo ldconfig
    cd ..
fi

echo;
echo 'Downloading and installing FLRIG...';
if [ -f "/usr/local/bin/flrig" ]; then
    echo 'flrig installed';
else
    wget http://www.w1hkj.com/files/flxmlrpc/flxmlrpc-0.1.4.tar.gz
    tar -zxvf flxmlrpc-0.1.4.tar.gz
    cd flxmlrpc-0.1.4
    ./configure --prefix=/usr/local --enable-static
    make
    sudo make install
    sudo ldconfig
    cd ..

    wget http://www.w1hkj.com/files/flrig/flrig-1.3.53.tar.gz
    tar -zxvf flrig-1.3.53.tar.gz
    cd flrig-1.3.53
    ./configure --prefix=/usr/local --enable-static
    make
    sudo make install
    cd ..
fi


echo;
echo 'Downloading and installing JS8Call...';
if [ -f "/usr/local/bin/js8call" ]; then
    echo 'JS8Call installed';
else
    wget http://files.js8call/com/2.2.0/js8call_2.2.0_armhf.deb
    sudo dpkg -i js8call_2.2.0_armhf.deb

    sudo apt --fix-broken install
    sudo dpkg -i js8call_2.2.0_armhf.deb
fi

echo;
echo 'Downloading and installing Direwolf...';
if [ -f "/usr/local/bin/direwolf" ]; then
    echo 'Direwolf installed';
else
    sudo apt-get -y install gcc
    sudo apt-get -y install g++
    sudo apt-get -y install make
    sudo apt-get -y install cmake
    sudo apt-get -y install libasound2-dev
    sudo apt-get -y install libudev-dev
    git clone https://www.github.com/wb2osz/direwolf.git

    cd direwolf
    mkdir build && cd build
    cmake ..
    make -j4
    sudo make install
    make install-conf
    cd ../..

    sudo apt-get -y install ax25-tools
    sudo apt-get -y install ax25-apps

    # update AX25 with callsign
    sed -i "s/YourCallSignHere/${callsign}/" ./axports
    cp ./axports /etc/ax25/axports


    ARECORD=$(arecord -l | grep 'USB Audio CODEC')
    RECORDCARD=$(echo ${ARECORD} | grep -o 'card [0-9]*')
    RECORDDEVICE=$(echo ${ARECORD} | grep -o 'device [0-9]*')
    AREC_CARD_NUM=$(echo ${RECORDCARD} | cut -d' ' -f2)
    AREC_DEVICE_NUM=$(echo ${RECORDDEVICE} | cut -d' ' -f2)
    sed -i "s/YourAudioCardNum/${AREC_CARD_NUM}/" ./direwolf.conf
    sed -i "s/YourAudioDeviceNum/${AREC_DEVICE_NUM}/" ./direwolf.conf
    sed -i "s/YourCallSignHere/${callsign}/" ./direwolf.conf

    # run `rigctl -l` to find a list of other radio models and swap the 373 here with that number.
    # Note that this script was writtin for and currently only supports the IC-705.
    # You'll need to additionally update your Ardop config and also your ~/.wl2k/config.json file to use a different rig.
    RIG='3085' # IC-705
    # run ls -l /dev/serial/by-id to determine the '/dev/ttyXXX' that your rig and GPS are assigned to
    RIG_SERIAL='/dev/ttyACM0'
    sed -i "s/YourRigNumberHere/${RIG}" ./direwolf.conf
    sed -i "s/YourRigSerialHere/${RIG_SERIAL}" ./direwolf.conf

fi

echo;
echo 'Downloading and installing Ardop TNC (beta)...';
if [ -f ${HOME}/.asoundrc ]; then
    echo 'Ardop exists';
else
    wget -O /tmp/ardopc http://www.cantab.net/users/john.wiseman/Downloads/Beta/piardopc;
    sudo install /tmp/ardopc /usr/local/bin;
    if [ "$(grep 'pcm\.ARDOP' ${HOME}/.asoundrc |wc -l)" -lt "1" ]; then
        echo 'pcm.ARDOP {type rate slave {pcm "hw:CARD=CODEC,DEV=0" rate 48000}}' >> ${HOME}/.asoundrc;
    fi
fi

echo;
echo 'Downloading and Installing Pat (pre-release 0.10.0)...';
if [ -f "/usr/bin/pat" ]; then
    echo 'pat installed';
else
    wget -O /tmp/pat_0.10.0_linux_armhf.deb https://github.com/la5nta/pat/releases/download/v0.10.0/pat_0.10.0_linux_armhf.deb;
    sudo dpkg -i /tmp/pat_0.10.0_linux_armhf.deb;
fi

echo;
echo 'Configuring Pat...';
mkdir -p ${HOME}/.wl2k;
if [ -e "${HOME}/.wl2k/config.json" ]; then
  echo 'Detected existing Pat configuration. Hit Enter to overwrite, or Ctrl+C to finish setup with existing config.';
  echo '(Note that run_pat.sh may not work as intended if you use an existing config.)';
  read continue;
fi;
wget -O ${HOME}/.wl2k/config.json https://raw.githubusercontent.com/KyleBrandon/pat-on-a-pi/main/pat_config.json;

sed -i "s/YourCallsignHere/${callsign}/" ${HOME}/.wl2k/config.json;

read -sp 'Enter your Winlink password (will not echo): ' wlpass;
sed -i "s/YourWinlinkPasswordHere/${wlpass}/" ${HOME}/.wl2k/config.json;
unset wlpass;
echo;

read -p 'Enter your Grid Square: ' gridsquare;
sed -i "s/YourGridSquareHere/${gridsquare}/" ${HOME}/.wl2k/config.json;

read -p 'Would you like to set up GPS as a time source (optional, beta)? [y/N]: ' setup_gps_time;
if [ "$setup_gps_time" == "y" ] || [ "$setup_gps_time" == "Y" ]; then
  ${HOME}/bin/gps_time_setup.sh;
fi

echo;
echo 'Congratulations, Pat has been installed and configured!';
echo "You can run it with the helper script: ${HOME}/bin/run_pat.sh";
echo "or the Run Pat icon on your desktop.";

