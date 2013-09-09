make_deb_distro
===============

Make your customized ubuntu/debian distribution for any target.

Depends on following ubuntu package :
realpath whois qemu-kvm-extras-static squashfs-tools extlinux mbr

```
This script build custom Ubuntu/Debian distributions.

./make-deb-distro [-a <action>] [OPTIONS]

Options:
        (-a|--action)            <action>                Action : install or uninstall.
        (-b|--target-device)     <device>                Target device
        (-c|--configuration)     <file>                  Configuration file
        (-d|--target-dir)        <path>                  Bootstrap path
        (-e|--excluded-packages) "<excluded-packages>" Packages to exclude from bootstrap process. List must be quoted.
        (-f|--only-rootfs)                               Build rootfs only
        (-h|--help)                                      Display this help message
        (-n|--distro-version)    <distro-name>           Debian/Ubuntu distribution name (same as host by default).
        (-o|--deb-packages)      "<deb-packages>"      Local .deb packages. List must be quoted.
        (-p|--packages)          "<packages>"          Distro packages to use. List must be quoted.
        (--script-rootfs)        <script>                Launch your script after rootfs is created and all package installed.
        (--script-prepare)       <script>                Launch your script to prepare the target device.
                                                         (/usr/share/make-deb-distro/scripts/profiles/default/prepare.sh by default)
        (--script-burn)          <script>                Launch your script to burn rootfs on target device.
                                                         (/usr/share/make-deb-distro/scripts/profiles/default/burn.sh by default)
        (-t|--target)            <target>                Target achitecture (same as host by default).
        (-v|--verbose)                                   Verbose mode
```
