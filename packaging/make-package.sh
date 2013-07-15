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

echo "Package: make-deb-distro
Version: 1.0
Section: Utilities
Priority: optional
Architecture: all
Depends: bash,realpath,whois,qemu-user-static,squashfs-tools,extlinux,mbr,debootstrap
Maintainer: Gilles DOFFE <gdoffe@gmail.com>
Description: Build a custom ubuntu/debian distro.
Homepage: https://github.com/gdoffe/make_deb_distro" > ${PKGDIR}/DEBIAN/control

dpkg-deb --verbose --build ${PKGDIR}
