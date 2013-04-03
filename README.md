make_deb_distro
===============

Make your customized ubuntu/debian distribution for any target.

Depends on following ubuntu package :
realpath whois qemu-kvm-extras-static squashfs-tools extlinux mbr

```
This script build custom Ubuntu/Debian distributions.

./make_distro.sh [-a <action>] [OPTIONS]

Options:
        (-a|--action)            <action>               Action : install or uninstall.
        (-b|--target-device)     <device>               Target device
        (-f|--only-rootfs)                              Build rootfs only
        (-h|--help)                                     Display this help message
        (-d|--target-dir)        <path>                 Bootstrap path
        (-o|--deb-packages)      "<deb_packages>"       Local .deb packages. List must be quoted.
        (-p|--packages)          "<packages>"           Distro packages to use. List must be quoted.
        (-r|--read-only)                                Read only distro
        (-t|--target)            <target>               Target achitecture (same as host by default)
        (-u|--excluded-packages) "<unwanted_packages>"  Packages to exclude from bootstrap process. List must be quoted.
        (-v|--verbose)                                  Verbose mode
```
