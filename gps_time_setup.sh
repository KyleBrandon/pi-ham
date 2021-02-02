#!/bin/bash
# Installs and configures gpsd and chrony to update the system clock via GPS when network unavailable.
# Thanks to OH8STN & G4WNC https://photobyte.org/raspberry-pi-stretch-gps-dongle-as-a-time-source-with-chrony-timedatectl/
# TODO: Add sanity checks to make sure steps go as planned (e.g. detect GPS actually working, detect NMEA listed in chronyc sources)

read -p 'Please close any other programs using your gps device and then hit Enter to continue.' gogo;

sudo apt -y install gpsd chrony gpsd-clients;

# Consider auto-detecting with grepping for 'source "/dev/tty.*" added' in dmesg output to make useful not only for IC-705
# IC-705 is ttyACM1, ublox shows as ttyACM0, my old BU-353 showed as ttyUSB0
device='ttyACM1';
sudo sed -i "s/DEVICES=.*/DEVICES=\"\/dev\/${device}\"/g" /etc/default/gpsd;
sudo sed -i 's/GPSD_OPTIONS=.*/GPSD_OPTIONS="-n"/g' /etc/default/gpsd;
sudo systemctl restart gpsd;

NMEA_already_configured=$(grep '^refclock.*refid NMEA' /etc/chrony/chrony.conf |wc -l)
if [ "$NMEA_already_configured" -eq "0" ]; then
  echo 'refclock SHM 0 offset 0.5 delay 0.2 refid NMEA' | sudo tee -a /etc/chrony/chrony.conf > /dev/null;
fi
read -p 'Completely disable Internet time sources (not recommended)? [y/N]: ' disable_nettime;
if [ "$disable_nettime" == "y" ] || [ "$disable_nettime" == "Y" ]; then
  sudo sed -i 's/pool/#pool/g' /etc/chrony/chrony.conf;
  echo 'Disabled network time. You can re-enable by running this script again and selecting n to the previous question.';
else
  echo 'Internet time left enabled. Note that your Pi will likely use an Internet time source over GPS when a network connection is present.';
fi
sudo systemctl restart chrony;

echo 'Setup complete! Your clock should be synchronized within the next minute or so.';

#if [ "$disable_nettime" ] || ...or if no network pool
# loop waiting for '#* NMEA' output in chronyc sources output