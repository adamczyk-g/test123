DISK="/dev/sda2"

mkdir -p /etc/restricted
chmod 0700 /etc/restricted
dd if=/dev/urandom of=/etc/restricted/luks.key bs=4096 count=1
cryptsetup luksAddKey $DISK /etc/restricted/luks.key
chown root:root /etc/restricted/luks.key
chmod 400 /etc/restricted/luks.key

cat << 'EOF' > /etc/initramfs-tools/hooks/pre-crypttab
#!/bin/sh
. /usr/share/initramfs-tools/hook-functions
copy_exec /etc/restricted/luks.key /cryptroot/luks.key
copy_exec /etc/crypttab "${DESTDIR}/cryptroot/crypttab"
exit 0
EOF

chmod +x /etc/initramfs-tools/hooks/pre-crypttab

update-initramfs -u

echo "Pamiętaj, aby zrestartować system."