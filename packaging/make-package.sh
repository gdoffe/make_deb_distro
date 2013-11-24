# Chack we are root
if [ $(id -u) != "0" ]; then
    echo "Error: Must be root to launch this script." > /dev/stderr
    exit 1
fi

# Create your scripts source dir
SRCDIR=../
PKGDIR=make-deb-distro
rm -Rf ${PKGDIR}
mkdir -p ${PKGDIR}/DEBIAN

# Copy your script to the source dir
mkdir -p ${PKGDIR}/usr/bin ${PKGDIR}/usr/share/make-deb-distro ${PKGDIR}/etc/make-deb-distro
cp ${SRCDIR}/make-deb-distro.sh ${PKGDIR}/usr/bin/make-deb-distro
cp -Rf ${SRCDIR}/make-deb-distro/profiles/ ${PKGDIR}/etc/make-deb-distro/
cp -Rf ${SRCDIR}/make-deb-distro/scripts ${PKGDIR}/usr/share/make-deb-distro/
cp -Rf ${SRCDIR}/make-deb-distro/templates ${PKGDIR}/usr/share/make-deb-distro/

installed_size=$(du -sb ${PKGDIR} | cut -s -f1)

echo "Package: make-deb-distro
Version: 0.1
Section: Utilities
Priority: optional
Architecture: all
Depends: bash,realpath,whois,qemu-user-static,qemu-system,binfmt-support,squashfs-tools,extlinux,mbr,debootstrap
Maintainer: Gilles DOFFE <gdoffe@gmail.com>
Description: Build a custom ubuntu/debian distro.
Homepage: https://github.com/gdoffe/make_deb_distro
Installed-Size: ${installed_size}" > ${PKGDIR}/DEBIAN/control

dpkg-deb --verbose --build ${PKGDIR}
