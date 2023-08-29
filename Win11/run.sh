#!/bin/bash

QEMU_DIR=$(cd $(dirname $0); pwd)
VM_NAME="Windows11"

swtpm socket --tpm2 --tpmstate dir=$QEMU_DIR/tpm --ctrl type=unixio,path=$QEMU_DIR/tpm/tpm-socket &


qemu-system-x86_64 \
-name $VM_NAME \
-rtc base=localtime,clock=host \
-global driver=cfi.pflash01,property=secure,value=on \
-drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2-ovmf/x64/OVMF_CODE.secboot.fd,unit=0 \
-drive if=pflash,format=raw,file=${QEMU_DIR}/OVMF_VARS.fd,unit=1 \
-m 4G -smp 4,sockets=1,cores=2,threads=2 \
-usb -device usb-tablet \
-machine type=q35,smm=on,accel=kvm \
-cpu host,hv_relaxed,hv_spinlocks=0x1fff,hv_vapic,hv_time,-hypervisor,+vmx \
-enable-kvm \
-drive format=raw,file=${QEMU_DIR}/windows11_img,index=0,media=disk,if=virtio \
-drive file=${QEMU_DIR}/iso/Win11_22H2_English_x64v2.iso,index=2,media=cdrom \
-drive file=${QEMU_DIR}/iso/virtio-win-0.1.229.iso,index=3,media=cdrom \
-global ICH9-LPC.disable_s3=1 \
-chardev socket,id=chrtpm,path=${QEMU_DIR}/tpm/tpm-socket \
-tpmdev emulator,id=tpm0,chardev=chrtpm \
-device ich9-intel-hda -device hda-output,audiodev=/dev/snd \
-audiodev pa,id=/dev/snd \
-device tpm-tis,tpmdev=tpm0 \
-device usb-ehci,id=ehci -device usb-host,hostbus=1,hostaddr=2 \
-net user,hostfwd=tcp::5555-:22 \
-net nic,macaddr=$(${QEMU_DIR}/../tools/qemu-mac-hasher.py "$VM_NAME") \
-vga qxl -device virtio-serial-pci \
-spice unix=on,addr=/tmp/vm_spice.socket,disable-ticketing=on \
-device virtserialport,chardev=spicechannel0,name=com.redhat.spice.0 \
-chardev spicevmc,id=spicechannel0,name=vdagent \
-display spice-app \
-daemonize

#if use wsl2, replace -cpu host to  -cpu  Skylake-Client-noTSX-IBRS

