#!/bin/bash

# Zmienna do przechowywania nazwy dysku
DISK=$(df / | tail -1 | awk '{print $1}')

# Zmienna do przechowywania nazwy zaszyfrowanej partycji
DISK_CRYPT="root-crypt"

echo "Szyfrowanie partycji: $DISK"

# Wykonaj szyfrowanie
echo "Rozpoczynanie szyfrowania partycji $DISK..."
cryptsetup-reencrypt $DISK --new --reduce-device-size 16M --type=luks1 --name $DISK_CRYPT

# Sprawdzenie, czy operacja się powiodła
if [ $? -ne 0 ]; then
    echo "Szyfrowanie nie powiodło się!"
    exit 1
fi

echo "Szyfrowanie zakończone pomyślnie."

# Otwórz zaszyfrowaną partycję
echo "Otwieranie zaszyfrowanej partycji..."
cryptsetup open $DISK $DISK_CRYPT

# Dostosowanie systemu plików
echo "Dostosowywanie systemu plików..."
resize2fs /dev/mapper/$DISK_CRYPT

# Montowanie katalogów w chroot
echo "Montowanie niezbędnych katalogów..."
mount --bind /dev /mnt/dev
mount --bind /dev/pts /mnt/dev/pts
mount --bind /sys /mnt/sys
mount --bind /proc /mnt/proc

# Montowanie zaszyfrowanej partycji
echo "Montowanie zaszyfrowanej partycji..."
mount /dev/mapper/$DISK_CRYPT /mnt

# Wejście do chroot
echo "Wejście do środowiska chroot..."
chroot /mnt

# Modyfikacja /etc/crypttab
UUID=$(blkid -s UUID -o value $DISK)
echo "$DISK_CRYPT /dev/disk/by-uuid/$UUID none luks" >> /etc/crypttab

# Modyfikacja /etc/fstab
echo "Zakomentowanie istniejącej linii dotyczącej partycji root w /etc/fstab..."
sed -i.bak "/$(echo $DISK | sed 's/\/dev\///')/s/^/#/" /etc/fstab

# Dodanie nowej linii do /etc/fstab
echo "/dev/mapper/$DISK_CRYPT / ext4 defaults 0 1" >> /etc/fstab

# Modyfikacja /etc/default/grub
sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"cryptdevice=\/dev\/$DISK:$DISK_CRYPT /" /etc/default/grub

# Zainstalowanie GRUB na odpowiednim dysku
echo "Instalowanie GRUB na $DISK..."
grub-install /dev/sda

# Aktualizacja konfiguracji GRUB i initramfs
update-grub
update-initramfs -k all -c

#wyjscie z chroot
exit

#zamknięcie partycji root
cryptsetup close $DISK_CRYPT

# Informacja końcowa
echo "Skonfigurowano /etc/crypttab, zakomentowano istniejącą linię w /etc/fstab oraz zaktualizowano GRUB."
echo "Pamiętaj, aby zrestartować system."