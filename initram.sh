DISK="/dev/sda2"

mkdir -p /cryptroot
chmod 0700 /cryptroot
dd if=/dev/urandom of=/cryptroot/luks.key bs=4096 count=1
cryptsetup luksAddKey $DISK /cryptroot/luks.key
chown root:root /cryptroot/luks.key
chmod 400 /cryptroot/luks.key

cat << 'EOF' > /etc/initramfs-tools/hooks/cp-crypttab-and-key
#!/bin/sh
. /usr/share/initramfs-tools/hook-functions
copy_exec /cryptroot/luks.key /cryptroot/luks.key
copy_exec /etc/crypttab "${DESTDIR}/cryptroot/crypttab"
exit 0
EOF

chmod +x /etc/initramfs-tools/hooks/cp-crypttab-and-key

update-initramfs -u

echo "Pamiętaj, aby zrestartować system."

#cryptsetup luksOpen /dev/sda2 root-crypt