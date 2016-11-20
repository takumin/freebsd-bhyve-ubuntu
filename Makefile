ARCH?=		amd64
VERSION?=	16.04
NETIF?=		tap0
DISK?=		/dev/zvol/zroot/bhyve/ubuntu

WORKDIR?=	${.CURDIR}/.temp
DOWNDIR?=	${.CURDIR}/.down

MIRROR_URL?=	http://ftp.jaist.ac.jp/pub/Linux/ubuntu/

.POSIX:

.PHONY: all
all: boot-grub

.PHONY: destdir
destdir: ${WORKDIR} ${DOWNDIR}
${WORKDIR}:
	@mkdir -p $@
${DOWNDIR}:
	@mkdir -p $@

.PHONY: download
download: destdir ${DOWNDIR}/ubuntu-minimal-12.04.iso ${DOWNDIR}/ubuntu-minimal-14.04.iso ${DOWNDIR}/ubuntu-minimal-16.04.iso
${DOWNDIR}/ubuntu-minimal-12.04.iso:
	@fetch -o $@ ${MIRROR_URL}/dists/precise/main/installer-${ARCH}/current/images/netboot/mini.iso
${DOWNDIR}/ubuntu-minimal-14.04.iso:
	@fetch -o $@ ${MIRROR_URL}/dists/trusty/main/installer-${ARCH}/current/images/netboot/mini.iso
${DOWNDIR}/ubuntu-minimal-16.04.iso:
	@fetch -o $@ ${MIRROR_URL}/dists/xenial/main/installer-${ARCH}/current/images/netboot/mini.iso

.PHONY: install-devmap
install-devmap: download ${WORKDIR}/install-12.04.map ${WORKDIR}/install-14.04.map ${WORKDIR}/install-16.04.map
${WORKDIR}/install-template.map:
	@echo "(hd0) ${DISK}" > $@
	@echo "(cd0) ${DOWNDIR}/ubuntu-minimal-@@VERSION@@.iso" >> $@
${WORKDIR}/install-12.04.map: ${WORKDIR}/install-template.map
	@sed -e 's/@@VERSION@@/12.04/' ${WORKDIR}/install-template.map > $@
${WORKDIR}/install-14.04.map: ${WORKDIR}/install-template.map
	@sed -e 's/@@VERSION@@/14.04/' ${WORKDIR}/install-template.map > $@
${WORKDIR}/install-16.04.map: ${WORKDIR}/install-template.map
	@sed -e 's/@@VERSION@@/16.04/' ${WORKDIR}/install-template.map > $@

.PHONY: install-grub
install-grub: install-devmap ${WORKDIR}/install-12.04.grub ${WORKDIR}/install-14.04.grub ${WORKDIR}/install-16.04.grub
${WORKDIR}/install-template.grub:
	@echo -n "linux (cd0)/linux" >> $@
	@echo -n " auto" >> $@
	@echo -n " locale=en_US" >> $@
	@echo -n " hostname=ubuntu" >> $@
	@echo " -- quiet splash" >> $@
	@echo "initrd (cd0)/initrd.gz" >> $@
	@echo "boot" >> $@
${WORKDIR}/install-12.04.grub: ${WORKDIR}/install-template.grub
	@sed -e 's/@@SUITE@@/suite=precise/' ${WORKDIR}/install-template.grub > $@
${WORKDIR}/install-14.04.grub: ${WORKDIR}/install-template.grub
	@sed -e 's/@@SUITE@@/suite=trusty/' ${WORKDIR}/install-template.grub > $@
${WORKDIR}/install-16.04.grub: ${WORKDIR}/install-template.grub
	@sed -e 's/@@SUITE@@/suite=xenial/' ${WORKDIR}/install-template.grub > $@

.PHONY: install-boot
install-boot: install-grub ${WORKDIR}/.install_done
${WORKDIR}/.install_done:
	@sudo bhyvectl --get-all --vm=ubuntu-${VERSION} > /dev/null && \
		sudo bhyvectl --destroy --vm=ubuntu-${VERSION} || echo -n ''
	@sudo grub-bhyve -M 1024 -m ${WORKDIR}/install-${VERSION}.map \
		ubuntu-${VERSION} < ${WORKDIR}/install-${VERSION}.grub > /dev/null
	@sudo bhyve -c 2 -m 1024M -H -P -A \
		-l bootrom,/usr/local/share/uefi-firmware/BHYVE_UEFI.fd \
		-l com1,/dev/nmdm0A \
		-s 0:0,hostbridge \
		-s 1:0,lpc \
		-s 2:0,virtio-net,${NETIF} \
		-s 3,ahci-cd,${DOWNDIR}/ubuntu-minimal-${VERSION}.iso \
		-s 4,virtio-blk,${DISK} ubuntu-${VERSION}
	@touch $@

.PHONY: boot-devmap
boot-devmap: install-boot ${WORKDIR}/boot-12.04.devmap ${WORKDIR}/boot-14.04.devmap ${WORKDIR}/boot-16.04.devmap
${WORKDIR}/boot-template.devmap:
	@echo "(hd0) /dev/zvol/zroot/bhyve/ubuntu" > $@
${WORKDIR}/boot-12.04.devmap: ${WORKDIR}/boot-template.devmap
	@cp ${WORKDIR}/boot-template.devmap $@
${WORKDIR}/boot-14.04.devmap: ${WORKDIR}/boot-template.devmap
	@cp ${WORKDIR}/boot-template.devmap $@
${WORKDIR}/boot-16.04.devmap: ${WORKDIR}/boot-template.devmap
	@cp ${WORKDIR}/boot-template.devmap $@

.PHONY: boot-grub
boot-grub: boot-devmap ${WORKDIR}/boot-12.04.grub ${WORKDIR}/boot-14.04.grub ${WORKDIR}/boot-16.04.grub
${WORKDIR}/boot-template.grub:
	@echo "set root(hd0,msdos1)" > $@
	@echo "linux /vmlinuz root=/dev/vda1" >> $@
	@echo "initrd /initrd.img" >> $@
	@echo "boot" >> $@
${WORKDIR}/boot-12.04.grub: ${WORKDIR}/boot-template.grub
	@cp ${WORKDIR}/boot-template.grub $@
${WORKDIR}/boot-14.04.grub: ${WORKDIR}/boot-template.grub
	@cp ${WORKDIR}/boot-template.grub $@
${WORKDIR}/boot-16.04.grub: ${WORKDIR}/boot-template.grub
	@cp ${WORKDIR}/boot-template.grub $@

.PHONY: clean
clean:
	@rm -fr ${WORKDIR}
