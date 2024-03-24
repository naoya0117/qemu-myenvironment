# [qemu-scripts](https://github.com/naoya0117/qemu-scripts)

- windows,Linuxの仮想環境をqemuで構築するときに使用したスクリプトファイルをまとめています.


## 使い方

- 必要なパッケージをインストールする
  
```
sudo pacman -S qemu-full swtpm edk2-ovmf
```

- ディレクトリを作る。guest_osディレクトリは好きな名前に読み替えること

```
mkdir qemu/toos qemu/guest_os qemu/guest_os/iso qemu/guest_os/tpm
```

- 以下のように本リポジトリのファイルを配置する(iso,tpmは空ディレクトリ)

```
qemu
├── tools
│   └── qemu-mac-hasher.py(本リポジトリのtools以下のスクリプト)
└── guest_os
    ├── iso
    ├── run.sh(本リポジトリのrun.shスクリプト)
    └── tpm
```

- qemu-mac-hasher.pyはrun.sh上の環境変数VM_NAME(後述)のハッシュ値からmacアドレスを生成する役割を持つ。
- qemu-mac-hasher.pyとrun.shに実行権限を付与する

```
chmod u+x /path/to/qemu-mac-hasher.py
chmod u+x /path/to/run.sh
```

- ゲストOSのOSイメージ(isoファイル)をisoディレクトリ直下に置く。Windowsの場合は別途ドライバが必要なため、https://github.com/virtio-win/virtio-win-pkg-scripts/blob/master/README.md のisoファイルも合わせて2つ配置する必要がある。
- UEFI環境を使用するため、guest_osディレクトリ直下にOVMF_VARS.fdを配置する。
  
```
cp /usr/share/ovmf/x64/OVMF_VARS.fd ~/path/to/guest_os/
```

- ストレージに該当するファイルをguest_osディレクトリ直下に生成する(Windowsゲストの場合は、最低要件の64G以上に設定する必要がある)
  
```
cd /path/to/guest_os
qemu-img create -f raw guest_os_img(好きな名前) 32G(サイズ)
```

- 実行スクリプトrun.shを環境に合わせて変更する(次の章を参照)
  
```
vim /path/to/run.sh
```

- 仮想マシンを起動する
  
```
/path/to/run.sh
```

- クリップボードの共有のため、spice-clientをゲストOSにインストールする。(windowsはhttps://www.spice-space.org/download.htmlで入手できる, また一部のLinuxディストリビューションにはデフォルトでインストールされている)
## run.shスクリプトを編集する
仮想マシンの実行に当たりrun.shを編集する必要がある。
- まず、変更が必要な部分は以下のとおりである。(Linuxの場合は、DRIVE_ISOは不要)
  
```
VM_NAME="Windows11"
OS_ISO="Win11_22H2_English_x64v2.iso"
DRIVER_ISO="virtio-win-0.1.229.iso"
IMG_FILE="windows11_img"
CAMERA_HOSTBUS=1
CAMERA_HOSTADDR=2
```
- VM_NAMEは仮想マシンごとに一意の名前とする。(好きな名前で良い)
- OS_ISO, DRIVER_ISOはisoファイルの名前である。
- IMG_FILEはqemu-imgで生成したimgファイルの名前である。
- CAMERA_HOSTBUS,CAMERA_HOSTADDR変数は以下の操作により求めることができる
  
```
$ lsusb

Bus 002 Device 001: ID 1d6b:0003 Linux Foundation 3.0 root hub
Bus 001 Device 003: ID 06cb:00a2 Synaptics, Inc. Metallica MOH Touch Fingerprint Reader
Bus 001 Device 002: ID 04ca:7070 Lite-On Technology Corp. Integrated Camera
Bus 001 Device 004: ID 8087:0aaa Intel Corp. Bluetooth 9460/9560 Jefferson Peak (JfP)
Bus 001 Device 001: ID 1d6b:0002 Linux Foundation 2.0 root hub
```

- 以上の名前からIntegrated Cameraっぽいものを探す。その行のBus,Deviceの値がそれぞれ、CAMERA_HOSTBUS,CAMERA_HOSTADDRの値となる。
- また、run.shを非特権ユーザで起動すると、deviceの権限エラーが起こることがある。以下の方法で回避する
    - 専用のグループを作り、ユーザに所属させる
      
        ```
        # groupadd video
        # usermod -G video $(whoami)
        ```
        
    - デバイス情報を取得する(cameraっぽい行のBus,Deviceの値に加えてx:yの部分を覚えておく)
      
        ```
        $ lsusb
        Bus 002 Device 001: ID 1d6b:0003 Linux Foundation 3.0 root hub
        Bus 001 Device 003: ID 06cb:00a2 Synaptics, Inc. Metallica MOH Touch Fingerprint Reader
        Bus 001 Device 002: ID 04ca:7070 Lite-On Technology Corp. Integrated Camera
        Bus 001 Device 004: ID 8087:0aaa Intel Corp. Bluetooth 9460/9560 Jefferson Peak (JfP)
        Bus 001 Device 001: ID 1d6b:0002 Linux Foundation 2.0 root hub
        ```
        
    - 起動時のデバイスの権限を変更するため以下の内容を追記する。(ATTRS{idVendor}の値が、上述したxの値,yの値がATTRS{idProduct}である)
      
        ```
        # vim /etc/udev/rules.d/83-webcam.rules

        SUBSYSTEM=="usb", ATTRS{idVendor}=="04ca", ATTRS{idProduct}=="7070",GROUP="video", MODE="0666"
        ```
        
    - 再起動する
      
        ```
        reboot
        ```
        
    - /dev/bus/usb/${BUS}/${DEVICE}の権限を確認する (所有グループがvideoであれば成功)
      
    ```
    ls -l /dev/bus/usb/001/002
    crw-rw-rw- 1 root video 189, 1 Sep 20 13:39 /dev/bus/usb/001/002
    ```

## example
```
Win11
├── iso
│   ├── virtio-win-0.1.229.iso
│   └── Win11_22H2_English_x64v2.iso
├── OVMF_VARS.fd
├── run.sh
├── tpm
│   └── tpm2-00.permall(auto-generate)
└── windows11_img
```
```
Xubuntu
├── iso
│   └── xubuntu-22.04.3-desktop-amd64.iso
├── OVMF_VARS.fd
├── run.sh
├── tpm
│   └── tpm2-00.permall(auto-generate)
└── xubuntu_img

```
## Links
- Repository: [https://github.com/naoya0117/qemu-scripts](https://github.com/naoya0117/qemu-scripts)
- Github: [https://github.com/naoya0117](https://github.com/naoya0117)
- Blog: [https://naoya0117.com](https://naoya0117.com)
  
