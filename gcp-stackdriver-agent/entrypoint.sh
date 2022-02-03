#!/bin/bash

echo "Mounting Disks"
lsblk -l 2>/dev/null| grep -v 'sda' | grep 'sd' | cut -d ' ' -f1 | xargs -I _ bash -c 'mkdir -p /mnt/_ && mount -o noload /dev/_  /mnt/_'

/etc/init.d/stackdriver-agent start

tail -f /dev/null
