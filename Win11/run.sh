#!/bin/bash

### Edit these variables ############
VM_NAME="Windows11"
OS_ISO="Win11_22H2_English_x64v2.iso"
DRIVER_ISO="virtio-win-0.1.229.iso"
IMG_FILE="windows11_img"
CAMERA_HOSTBUS=1
CAMERA_HOSTADDR=2
#####################################

#if you wanto to use ssh, you can use this port
#ex. ssh -p 5555 username@localhost (when sshd is running)
GUEST_PORT=22
HOST_PORT=5555


QEMU_DIR=$(cd $(dirname $0); pwd)
SOCKET=/tmp/vm_spice.socket

while getopts "cd" opt; do
  case ${opt} in
    c)
        remote-viewer spice+unix://${SOCKET} 1>/dev/null 2>&1  &
        exit 0
        ;;
    d)
        daemon=true
        ;;
    *)
        echo "Usage: $0 [-d]"
        exit 1
        ;;
  esac
done

if [[ -e ${SOCKET} ]]; then
    echo "Error: VM is already running?" 1>&2
    exit 1
fi


swtpm socket --tpm2 --tpmstate dir=$QEMU_DIR/tpm --ctrl type=unixio,path=$QEMU_DIR/tpm/tpm-socket &

{
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
-drive format=raw,file=${QEMU_DIR}/${IMG_FILE},index=0,media=disk,if=virtio \
-drive file=${QEMU_DIR}/iso/${OS_ISO},index=2,media=cdrom \
-drive file=${QEMU_DIR}/iso/${DRIVER_ISO},index=3,media=cdrom \
-global ICH9-LPC.disable_s3=1 \
-chardev socket,id=chrtpm,path=${QEMU_DIR}/tpm/tpm-socket \
-tpmdev emulator,id=tpm0,chardev=chrtpm \
-device ich9-intel-hda -device hda-output,audiodev=/dev/snd \
-audiodev pa,id=/dev/snd \
-device tpm-tis,tpmdev=tpm0 \
-device usb-ehci,id=ehci -device usb-host,hostbus=${CAMERA_HOSTBUS},hostaddr=${CAMERA_HOSTADDR} \
-net user,hostfwd=tcp::${HOST_PORT}-:${GUEST_PORT} \
-net nic,macaddr=$(${QEMU_DIR}/../tools/qemu-mac-hasher.py "$VM_NAME") \
-vga qxl -device virtio-serial-pci \
-spice unix=on,addr=${SOCKET},disable-ticketing=on \
-device virtserialport,chardev=spicechannel0,name=com.redhat.spice.0 \
-chardev spicevmc,id=spicechannel0,name=vdagent \
-acpitable file="${QEMU_DIR}/acpi/msdm.bin" \
-device ich9-usb-ehci1,id=usb \
-device ich9-usb-uhci1,masterbus=usb.0,firstport=0,multifunction=on \
-device ich9-usb-uhci2,masterbus=usb.0,firstport=2 \
-device ich9-usb-uhci3,masterbus=usb.0,firstport=4 \
-chardev spicevmc,name=usbredir,id=usbredirchardev1 -device usb-redir,chardev=usbredirchardev1,id=usbredirdev1 \
-chardev spicevmc,name=usbredir,id=usbredirchardev2 -device usb-redir,chardev=usbredirchardev2,id=usbredirdev2 \
-chardev spicevmc,name=usbredir,id=usbredirchardev3 -device usb-redir,chardev=usbredirchardev3,id=usbredirdev3 2>/dev/null & 
wait $(pidof qemu-system-x86_64)
rm -f ${SOCKET} &
} &

[ daemon ] || remote-viewer spice+unix://${SOCKET} 1>/dev/null 2>&1  &



#if use wsl2, replace -cpu host to  -cpu  Skylake-Client-noTSX-IBRS
# you can put windows productkey in ${QEMU_DIR}/acpi/msdm.bin and use it with -acpitable file="${QEMU_DIR}/acpi/msdm.bin" 
