#!/bin/bash

QEMU_DIR=$(cd $(dirname $0); pwd)
VM_NAME="Xubuntu"

swtpm socket --tpm2 --tpmstate dir=$QEMU_DIR/tpm --ctrl type=unixio,path=$QEMU_DIR/tpm/tpm-socket &


qemu-system-x86_64 \
-name $VM_NAME \
-rtc base=localtime,clock=host \
-global driver=cfi.pflash01,property=secure,value=on \
-drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2-ovmf/x64/OVMF_CODE.secboot.fd,unit=0 \
-drive if=pflash,format=raw,file=${QEMU_DIR}/OVMF_VARS.fd,unit=1 \
-m 4G -smp 4,sockets=1,cores=2,threads=2 \
-machine type=q35,smm=on,accel=kvm \
-cpu host,hv_relaxed,hv_spinlocks=0x1fff \
-enable-kvm \
-drive format=raw,file=${QEMU_DIR}/xubuntu_img,index=0,media=disk,if=virtio \
-drive file=${QEMU_DIR}/iso/xubuntu-22.04.3-desktop-amd64.iso,index=2,media=cdrom \
-global ICH9-LPC.disable_s3=1 \
-chardev socket,id=chrtpm,path=${QEMU_DIR}/tpm/tpm-socket \
-tpmdev emulator,id=tpm0,chardev=chrtpm \
-device tpm-tis,tpmdev=tpm0 \
-device ich9-intel-hda -device hda-output,audiodev=/dev/snd \
-audiodev pa,id=/dev/snd \
-device usb-ehci,id=ehci -device usb-host,hostbus=1,hostaddr=2 \
-net user,hostfwd=tcp::6666-:22 \
-net nic,macaddr=$(${QEMU_DIR}/../tools/qemu-mac-hasher.py "$VM_NAME") \
-vga qxl -device virtio-serial-pci \
-spice unix=on,addr=/tmp/vm_spice.socket,disable-ticketing=on \
-device virtserialport,chardev=spicechannel0,name=com.redhat.spice.0 \
-chardev spicevmc,id=spicechannel0,name=vdagent \
-display spice-app \
-daemonize \
${@}

#-usb -device usb-tablet \
