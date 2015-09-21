WORKDIR?=	${.CURDIR}/.temp
DOWNDIR?=	${.CURDIR}/.down

ARCH?=		amd64
VERSION?=	14.04
DISK?=		/dev/zvol/zroot/bhyve/ubuntu

UBUNTU_MIRROR_BASE?=	http://www.ftp.ne.jp/Linux/packages/ubuntu/archive/
UBUNTU_PRESEED_URL?=	http://192.168.0.100:8000/linux/ubuntu/preseed.cfg.php

.POSIX:

.PHONY: all
all: install-boot

.PHONY: destdir
destdir: ${WORKDIR} ${DOWNDIR}
${WORKDIR}:
	@mkdir -p $@
${DOWNDIR}:
	@mkdir -p $@

.PHONY: download
download: destdir ${DOWNDIR}/ubuntu-minimal-12.04.iso ${DOWNDIR}/ubuntu-minimal-14.04.iso ${DOWNDIR}/ubuntu-minimal-15.04.iso
${DOWNDIR}/ubuntu-minimal-12.04.iso:
	@fetch -o $@ ${UBUNTU_MIRROR_BASE}/dists/precise/main/installer-${ARCH}/current/images/netboot/mini.iso
${DOWNDIR}/ubuntu-minimal-14.04.iso:
	@fetch -o $@ ${UBUNTU_MIRROR_BASE}/dists/trusty/main/installer-${ARCH}/current/images/netboot/mini.iso
${DOWNDIR}/ubuntu-minimal-15.04.iso:
	@fetch -o $@ ${UBUNTU_MIRROR_BASE}/dists/vivid/main/installer-${ARCH}/current/images/netboot/mini.iso

.PHONY: install-devmap
install-devmap: download ${WORKDIR}/install-12.04.map ${WORKDIR}/install-14.04.map ${WORKDIR}/install-15.04.map
${WORKDIR}/install-template.map:
	@echo "(hd0) ${DISK}" > $@
	@echo "(cd0) ${DOWNDIR}/ubuntu-minimal-@@VERSION@@.iso" >> $@
${WORKDIR}/install-12.04.map: ${WORKDIR}/install-template.map
	@sed -e 's/@@VERSION@@/12.04/' ${WORKDIR}/install-template.map > $@
${WORKDIR}/install-14.04.map: ${WORKDIR}/install-template.map
	@sed -e 's/@@VERSION@@/14.04/' ${WORKDIR}/install-template.map > $@
${WORKDIR}/install-15.04.map: ${WORKDIR}/install-template.map
	@sed -e 's/@@VERSION@@/15.04/' ${WORKDIR}/install-template.map > $@

.PHONY: install-grub
install-grub: install-devmap ${WORKDIR}/install-12.04.grub ${WORKDIR}/install-14.04.grub ${WORKDIR}/install-15.04.grub
${WORKDIR}/install-template.grub:
	@echo -n "linux (cd0)/linux" >> $@
	@echo -n " auto" >> $@
	@echo -n " locale=en_US" >> $@
	@echo -n " hostname=ubuntu" >> $@
	@echo -n " preseed/url=${UBUNTU_PRESEED_URL}?@@SUITE@@" >> $@
	@echo "-- quiet splash" >> $@
	@echo "initrd (cd0)/initrd.gz" >> $@
	@echo "boot" >> $@
${WORKDIR}/install-12.04.grub: ${WORKDIR}/install-template.grub
	@sed -e 's/@@SUITE@@/suite=precise/' ${WORKDIR}/install-template.grub > $@
${WORKDIR}/install-14.04.grub: ${WORKDIR}/install-template.grub
	@sed -e 's/@@SUITE@@/suite=trusty/' ${WORKDIR}/install-template.grub > $@
${WORKDIR}/install-15.04.grub: ${WORKDIR}/install-template.grub
	@sed -e 's/@@SUITE@@/suite=vivid/' ${WORKDIR}/install-template.grub > $@

.PHONY: install-boot
install-boot: install-grub
	@sudo bhyvectl --get-all --vm=ubuntu-${VERSION} > /dev/null && \
		sudo bhyvectl --destroy --vm=ubuntu-${VERSION} || echo -n ''
	@sudo grub-bhyve -M 1024 -m ${WORKDIR}/install-${VERSION}.map \
		ubuntu-${VERSION} < ${WORKDIR}/install-${VERSION}.grub
	@sudo bhyve -c 2 -m 1024M -H -P -A \
		-l com1,stdio \
		-s 0:0,hostbridge \
		-s 1:0,lpc \
		-s 2:0,virtio-net,tap0 \
		-s 3,ahci-cd,${DOWNDIR}/ubuntu-minimal-${VERSION}.iso \
		-s 4,virtio-blk,${DISK} ubuntu-${VERSION}

.PHONY: clean
clean:
	@rm -fr ${WORKDIR}
