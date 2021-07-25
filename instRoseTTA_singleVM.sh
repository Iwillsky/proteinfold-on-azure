#!/bin/bash

#Mount data disk
sudo parted /dev/sdc --script mklabel gpt mkpart xfspart xfs 0% 100%
sudo mkfs.xfs /dev/sdc1
sudo partprobe /dev/sdc1
sudo mkdir /data
sudo mount /dev/sdc1 /data
sudo chmod 777 /data
sudo blkid     #Remeber UUID value of /dev/sdc1 
sudo vi /etc/fstab    #Add line with just UUID string: UUID=xxxxxxxx-xx…xxxx /data xfs defaults, nofail 1 2
lsblk -o NAME,HCTL,SIZE,MOUNTPOINT | grep -i "sd"


