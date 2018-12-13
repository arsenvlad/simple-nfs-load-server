#!/bin/bash

zypper refresh
zypper install -y sysstat dstat mdadm nfs-kernel-server nfs-client

# Get all data disks via symlinks created by Azure udev rules
DATA_DISKS=($(ls -d /dev/disk/azure/scsi1/*))
DATA_DISKS_COUNT=${#DATA_DISKS[@]}

# Create stripe set (RAID0) using the data disks
mdadm --create /dev/md0 --level=stripe --raid-devices=$DATA_DISKS_COUNT ${DATA_DISKS[@]}

# Make file system
mkfs -t ext4 -E nodiscard /dev/md0
mkdir -p /data

# Edit fstab to mount the device by blkid UUID
read UUID FS_TYPE < <(blkid -u filesystem /dev/md0|awk -F "[= ]" '{print $3" "$5}'|tr -d "\"")
echo "UUID=\"${UUID}\" /data ${FS_TYPE} defaults,nofail 1 2" >> /etc/fstab

# Mount file system
mount -a

# Check free space
df -H

# Backup mdadm configuration
mdadm --verbose --detail --scan >> /etc/mdadm.conf

# Configure NFS service to start
systemctl enable rpcbind.service
systemctl start rpcbind.service
systemctl enable nfsserver.service
systemctl start nfsserver.service

systemctl status nfsserver.service

# Conigure NFS export
echo "/data *(rw,sync,no_subtree_check)" >> /etc/exports
exportfs -a
systemctl restart nfsserver.service
showmount -e

# Download AzCopy v10
cd /root
wget https://azcopyvnext.azureedge.net/release20181102/azcopy_linux_amd64_10.0.4.tar.gz
tar xvf azcopy_linux_amd64_10.0.4.tar.gz
cp -f azcopy_linux_amd64_10.0.4/azcopy /usr/bin

# Download AzCopy v8
mkdir azcopy_v8
cd azcopy_v8
wget -O azcopy.tar.gz https://aka.ms/downloadazcopylinux64
tar xvf azcopy.tar.gz




