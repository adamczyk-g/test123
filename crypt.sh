#!/bin/bash

# Zmienna do przechowywania nazwy dysku
DISK="/dev/sda2" 

# Zmienna do przechowywania nazwy zaszyfrowanej partycji
DISK_CRYPT="root-crypt" 

echo "Szyfrowanie partycji: $DISK" 

e2fsck -f -p $DISK
resize2fs -M $DISK

# Wykonaj szyfrowanie
echo "Rozpoczynanie szyfrowania partycji $DISK..." 
cryptsetup reencrypt --encrypt --reduce-device-size 16M --type=luks1 $DISK

# Sprawdzenie, czy operacja się powiodła
if [ $? -ne 0 ]; then
    echo "Szyfrowanie nie powiodło się!" 
    exit 1
fi

echo "Szyfrowanie zakończone." 

# Otwórz zaszyfrowaną partycję
echo "Otwieranie zaszyfrowanej partycji..." 
cryptsetup open $DISK $DISK_CRYPT

# Dostosowanie systemu plików
echo "Dostosowywanie systemu plików..." 
e2fsck -f -p /dev/mapper/$DISK_CRYPT
resize2fs /dev/mapper/$DISK_CRYPT

# Montowanie zaszyfrowanej partycji
echo "Montowanie zaszyfrowanej partycji..." 
mount /dev/mapper/$DISK_CRYPT /mnt

# Montowanie katalogów dla chroot
echo "Montowanie niezbędnych katalogów..." 
mount --bind /dev /mnt/dev
mount --bind /dev/pts /mnt/dev/pts
mount --bind /sys /mnt/sys
mount --bind /proc /mnt/proc

# Modyfikacja /etc/crypttab
UUID=$(blkid -s UUID -o value $DISK)
echo "UUID=$UUID" 
echo "DISK_CRYPT=$DISK_CRYPT" 
#echo "$DISK_CRYPT UUID=$UUID none luks" >> /mnt/etc/crypttab
echo "$DISK_CRYPT $DISK none luks" >> /mnt/etc/crypttab
cat /mnt/etc/crypttab

# Modyfikacja /etc/fstab
echo "Zakomentowanie istniejącej linii dotyczącej partycji root w /etc/fstab..." 
sed -i '/\/ ext4/ s/^/#/' /mnt/etc/fstab

# Dodanie nowej linii do /etc/fstab
echo "/dev/mapper/$DISK_CRYPT / ext4 defaults 0 1" >> /mnt/etc/fstab
cat /mnt/etc/fstab
# Modyfikacja /etc/default/grub
echo "GRUB_ENABLE_CRYPTODISK=y" >> /mnt/etc/default/grub
###

# Wejście do chroot
echo "Wejście do środowiska chroot..." 
chroot /mnt /bin/bash << 'EOF'
echo 'Hello from chroot!'
# Zainstalowanie GRUB
grub-install /dev/sda

# Aktualizacja konfiguracji GRUB i initramfs
update-grub
update-initramfs -k all -c

#wyjscie z chroot
exit
EOF

#echo "odmontowanie /mnt" 
#umount /mnt
#zamknięcie partycji root
#cryptsetup close $DISK_CRYPT

echo "Pamiętaj, aby zrestartować system." 