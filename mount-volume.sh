#!/bin/bash

modprobe fuse
mount -t glusterfs odroid-brick1:/v01 /home/odroid/gluster-volume
