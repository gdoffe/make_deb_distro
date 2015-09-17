# Chack we are root
if [ $(id -u) != "0" ]; then
    echo "Error: Must be root to launch this script." > /dev/stderr
    exit 1
fi

# Delete all deb files
rm -f *.deb

# Create your scripts source dir
SRCDIR=../
PKGDIR=make-deb-distro
rm -Rf ${PKGDIR}
mkdir -p ${PKGDIR}/DEBIAN

# Copy your script to the source dir
mkdir -p ${PKGDIR}/usr/bin ${PKGDIR}/usr/share/make-deb-distro ${PKGDIR}/etc/make-deb-distro ${PKGDIR}/usr/share/doc/make-deb-distro
cp ${SRCDIR}/make-deb-distro.sh ${PKGDIR}/usr/bin/make-deb-distro
cp -Rf ${SRCDIR}/make-deb-distro/profiles/ ${PKGDIR}/etc/make-deb-distro/
cp -Rf ${SRCDIR}/make-deb-distro/scripts ${PKGDIR}/usr/share/make-deb-distro/
cp -Rf ${SRCDIR}/make-deb-distro/templates ${PKGDIR}/usr/share/make-deb-distro/
gzip -c -9 ${SRCDIR}/changelog > ${PKGDIR}/usr/share/doc/make-deb-distro/changelog.gz
cp ${SRCDIR}/copyright ${PKGDIR}/usr/share/doc/make-deb-distro/copyright


installed_size=$(du -s ${PKGDIR} | cut -s -f1)

echo "/etc/make-deb-distro/profiles/default/default.conf
/etc/make-deb-distro/profiles/read-only/read-only.conf" > ${PKGDIR}/DEBIAN/conffiles

echo "Package: make-deb-distro
Version: 0.3
Section: utils
Priority: optional
Architecture: all
Depends: realpath,whois,qemu-user-static,qemu-system,binfmt-support,squashfs-tools,extlinux,mbr,debootstrap
Maintainer: Gilles DOFFE <gdoffe@gmail.com>
Description: Build a custom ubuntu/debian distro.
 Build a full customized ubuntu or debian distro for all supported targets.
Homepage: https://github.com/geonobot/make_deb_distro
Installed-Size: ${installed_size}" > ${PKGDIR}/DEBIAN/control

#echo "Format: http://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
#Upstream-Name: make-deb-distro
#Source: https://github.com/geonobot/make_deb_distro
#
#Files: *
#Copyright: Copyright (C) 2013 Gilles DOFFE <gdoffe@gmail.com>
#License: GPL-3
# This program is free software; you can redistribute it
# and/or modify it under the terms of the GNU General Public
# License as published by the Free Software Foundation; either
# version 3 of the License, or (at your option) any later
# version.
# .
# This program is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
# PURPOSE.  See the GNU General Public License for more
# details.
# .
# You should have received a copy of the GNU General Public
# License along with this package; if not,
# see <http://www.gnu.org/licenses/>.
# .
# On Debian systems, the full text of the GNU General Public
# License version 3 can be found in the file
# /usr/share/common-licenses/GPL-3.
#
#Files: debian/*
#Copyright: Copyright 2013 Gilles DOFFE <gdoffe@gmail.com>
#License: GPL-3
# [LICENSE TEXT]" > ${PKGDIR}/DEBIAN/copyright

dpkg-deb --debug --verbose --build ${PKGDIR}
