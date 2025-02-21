#!/bin/bash

# 설정
TARGET_DISK="/dev/vda"
TARGET_MOUNT="/mnt"
UBUNTU_VERSION="noble"  # 22.04 LTS
MIRROR="http://archive.ubuntu.com/ubuntu"

echo "[1/6] disk partitioning"
# 기존 데이터 삭제 (주의!)
sgdisk --zap-all ${TARGET_DISK}

# EFI 파티션과 루트 파티션 생성
parted -s ${TARGET_DISK} mklabel gpt
parted -s ${TARGET_DISK} mkpart ESP fat32 1MiB 512MiB
parted -s ${TARGET_DISK} set 1 boot on
parted -s ${TARGET_DISK} mkpart primary ext4 512MiB 100%

# 파일시스템 생성
mkfs.vfat -F32 ${TARGET_DISK}1
mkfs.ext4 ${TARGET_DISK}2

# 마운트
mount ${TARGET_DISK}2 ${TARGET_MOUNT}
mkdir -p ${TARGET_MOUNT}/boot/efi
mount ${TARGET_DISK}1 ${TARGET_MOUNT}/boot/efi

echo "[2/6] debootstrap"
apt update
apt install -y debootstrap

debootstrap --arch=amd64 ${UBUNTU_VERSION} ${TARGET_MOUNT} ${MIRROR}

echo "[3/6] setting fstab"
cat <<EOF > ${TARGET_MOUNT}/etc/fstab
UUID=$(blkid -s UUID -o value ${TARGET_DISK}2) / ext4 defaults 0 1
UUID=$(blkid -s UUID -o value ${TARGET_DISK}1) /boot/efi vfat defaults 0 1
EOF

echo "[4/6] install systemd-boot"
mount --bind /dev ${TARGET_MOUNT}/dev
mount --bind /proc ${TARGET_MOUNT}/proc
mount --bind /sys ${TARGET_MOUNT}/sys

chroot ${TARGET_MOUNT} bash -c "
cat <<EOF > /etc/apt/sources.list
deb $MIRROR $UBUNTU_VERSION main restricted universe multiverse
deb-src $MIRROR $UBUNTU_VERSION main restricted universe multiverse

deb $MIRROR $UBUNTU_VERSION-security main restricted universe multiverse
deb-src $MIRROR $UBUNTU_VERSION-security main restricted universe multiverse

deb $MIRROR $UBUNTU_VERSION-updates main restricted universe multiverse
deb-src $MIRROR $UBUNTU_VERSION-updates main restricted universe multiverse
EOF

apt update
apt install -y systemd-boot
bootctl install

# 부팅 옵션 설정
mkdir -p /boot/efi/loader/entries
cat <<BOOT > /boot/efi/loader/entries/ubuntu.conf
title Ubuntu ${UBUNTU_VERSION}
linux /vmlinuz
initrd /initrd.img
options root=UUID=$(blkid -s UUID -o value ${TARGET_DISK}2) rw quiet splash
BOOT

# 부트로더 기본 설정
cat <<LOADER > /boot/efi/loader/loader.conf
default ubuntu.conf
timeout 3
LOADER
"

echo "[5/6] 사용자 설정"
chroot ${TARGET_MOUNT} bash -c "
echo 'ubuntu' > /etc/hostname
echo 'root:password' | chpasswd
"

echo "[6/6] 설치 완료 - 재부팅 준비"
umount -R ${TARGET_MOUNT}
echo "설치 완료! 재부팅하세요."
