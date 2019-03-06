# Removing MATE packages

## Uninstall mate-desktop
To remove just mate-desktop package itself from Ubuntu 16.04 (Xenial Xerus) execute on terminal:  
`sudo apt-get remove ubuntu-mate-desktop`

## Uninstall mate-desktop and it's dependencies
To remove the mate-desktop package and any other dependent package which are no longer needed from Ubuntu Xenial:  
`sudo apt-get remove --auto-remove ubuntu-mate-desktop`

## Purging mate-desktop
If you also want to delete configuration and/or data files of mate-desktop from Ubuntu Xenial:  
`sudo apt-get purge ubuntu-mate-desktop`

## Purging mate-desktop and it's dependencies
To delete configuration and/or data files of mate-desktop and it's dependencies from Ubuntu Xenial then execute:  
`sudo apt-get purge --auto-remove ubuntu-mate-desktop`

## To remove x11 and everything that uses it, including all configuration
`sudo apt-get purge libx11.* libqt.*`
