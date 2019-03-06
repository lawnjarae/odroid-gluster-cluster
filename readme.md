# Odroid XU4/HC2 Gluster NAS Setup

This document contains information on configuring a Gluster cluster using Odroid's HC2 and XU4 single board computers.
In my case, the cluster contains three HC2's configured as a Gluster cluster and one XU4 as the main SMB share point.
The Samba share will be auto-detected by Finder in OSX.
The OS of choice was Ubuntu MATE (though I've been told Ubuntu minimal would also work).

For the purposes of this article the single user across every device will be `odroid`.

## Hardware
- Three Odroid HC2's
    - Hostnames are `odroid-brick1`, `odroid-brick2`, and `odroid-brick3`
- One Odroid XU4
- OS - Ubuntu MATE (18.04?)
- 32GB SD cards
- Three 6TB hard drives

## Basic Setup
These commands should be run on every HC2 and XU4 in your architecture.
Most of this information was pulled from the [Odroid Wiki](https://wiki.odroid.com/odroid-xu4/software/ubuntu_nas/01_basic_settings).

Several of these wizards will prompt you to select a locale.
Select **en_US.UTF-8** for all of the steps.

    $ sudo locale-gen "en_US.UTF-8"
    $ sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
    $ sudo dpkg-reconfigure locales
    $ sudo dpkg-reconfigure tzdata

If you'd like to remove MATE Desktop, follow these steps:

    $ sudo apt-get purge --auto-remove ubuntu-mate-desktop
    $ sudo apt-get purge --auto-remove ubuntu-mate-core
    $ sudo apt-get purge --auto-remove libx11.* libqt.*
    $ sudo apt install man-db vim

Now that the locales and timezones have been set, update the system and reboot.

    $ sudo apt update && sudo apt full-upgrade
    $ sudo reboot now

## Update the `hosts` File
In your router's configuration, ensure that all HC2's and the XU4 are receiving static IP's and NOT getting anything via DHCP.
Once the IP's are known, log into each HC2 and the XU4 and configure the `hosts` file so that every device knows about each other.

Example:

    192.168.1.10	odroid-brick1
    192.168.1.11	odroid-brick2
    192.168.1.12	odroid-brick3
    192.168.1.13	xu4

## Disabling Root SSH Access
Edit the `sshd_config`:
`$ sudo vi /etc/ssh/sshd_config`  

Find "PermitRootLogin" and change it to "no":
`$ sudo service sshd restart`

## Formatting the Hard Drives
It is recommended to use XFS in a Gluster cluster.

Install `xfsprogs`:
`$ sudo apt-get install xfsprogs`

The next set of commands should be executed as `root`.
Format the drive, in this case located at `/dev/sda`, to XFS.
Next, create a directory that will be the mount point for our hard drive.
I created these folders to match the name of the HC2 unit I was on.
e.g. brick1 = /data/brick1; brick2 = /data/brick2; etc.
Once the folder is created, echo the mount information into the `fstab` and mount the drive.

    # mkfs.xfs -i size=512 /dev/sda
    // Next few commands have a unique brick number folder.
    # mkdir -p /data/brick[1..3]
    # echo '/dev/sda /data/brick[1..3] xfs defaults 1 2' >> /etc/fstab
    # mount -a && mount

## Setting up the Gluster Cluster
I recommend reading the official docs on how to configure Gluster. They can be found [here](https://docs.gluster.org/en/latest/Quick-Start-Guide/Quickstart/#installing-glusterfs-a-quick-start-guide).

### Install the Gluster Repository and Gluster Packages
    $ sudo add-apt-repository ppa:gluster/glusterfs-5
    $ sudo apt-get update
    $ sudo apt install glusterfs-server

Start glusterd and enable the service

    $ sudo systemctl start glusterd
    $ sudo systemctl enable glusterd

### Create the Gluster Volume
For each of the bricks, create a folder in the mount location:
`$ sudo mkdir -p /data/brick[1..3]/gv0`

From the first brick, `odroid-brick1`, add the other bricks as peers:
`$ sudo gluster peer probe odroid-brick2 odroid-brick3`

From the first brick, create a volume, `v01`, that consists of the three bricks:
`$ sudo gluster volume create v01 odroid-brick1:/data/brick1/gv0/ odroid-brick2:/data/brick2/gv0 odroid-brick3:/data/brick3/gv0`

### Mount the Gluster Volume
From the XU4, create a folder to where the Gluster volume will be mounted.

Example mount command:
`# mount -t glusterfs odroid-brick1:/v01 /mnt/glusterfs`

## Installing and Configuring Samba
This configuration is done from the XU4.
Ensure that the Gluster volume is already mounted in a desired location.
This configuration uses `/home/odroid/gluster-volume` as the mount point.

Install Samba and enable the service:

    $ sudo apt-get install libcups2 samba samba-common
    $ sudo systemctl enable smbd
    $ sudo systemctl start smbd

### Edit the `/etc/samba/smb.conf` file

The added configuration will create a guest account and assign anyone logging in as `guest` the user `odroid`.
Optional, configure the `map to guest` parameter such that a bad login is treated as guest. **THIS IS NOT GREAT SECURITY!!!**

Configuration (added or modified fields only):

    [global]
    guest account = odroid
    workgroup = ODROID
    map to guest = bad user
    usershare allow guests = yes

    # The name of the SMB share
    [OdroidNAS]
       # Path to the mounted volume
       path = /home/odroid/gluster-volume
       guest ok = yes
       read only = no
       writeable = yes

       # Hide hidden files by default
       hide dot files = yes

       # Configure fruit to deal with Apple's garbage filesystem
       # These options are configurable. Check the docs for the possible values
       vfs objects = recycle fruit streams_xattr
       fruit:aapl = yes
       fruit:encoding = native
       fruit:locking = none
       fruit:metadata = stream
       fruit:resource = file
       recycle:repository = .recycle
       recycle:keeptree = yes
       recycle:versions = yes

Once the configuration has been updated, restart the `smbd` service:
`$ sudo service smbd restart`

### Make SMB Share Discoverable
This will allow Finder to see the SMB share labeled `OdroidNAS`.

Install the required packages:
`$ sudo apt-get install avahi-daemon avahi-utils`

Create the file `/etc/avahi/services/smb.service` and add the following to it:

    <?xml version="1.0" standalone='no'?>
    <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
    <service-group>
     <name replace-wildcards="yes">%h</name>
     <service>
       <type>_smb._tcp</type>
       <port>445</port>
     </service>
    </service-group>

Enable the service and restart `smbd`:

    $ sudo systemctl enable avahi-daemon
    $ sudo systemctl start avahi-daemon
    $ sudo systemctl restart
