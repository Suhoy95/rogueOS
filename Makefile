
CC := x86_64-w64-mingw32-gcc
CPPFLAGS := -I"../gnu-efi-3.0.8/inc/" \
			-I"../gnu-efi-3.0.8/inc/x86_64" \
			-I"../gnu-efi-3.0.8/inc/protocol"

BOOTX64.EFI: hello.o data.o
	$(CC) -nostdlib -Wl,-dll -shared -Wl,--subsystem,10 -e efi_main -o $@ $^ -lgcc

hello.o: hello.c
	$(CC) -ffreestanding $(CPPFLAGS) -c -o $@ $^

data.o: data.c
	$(CC) -ffreestanding $(CPPFLAGS) -c -o $@ $^

fat.img: BOOTX64.EFI
	dd if=/dev/zero of=$@ bs=1k count=1440
	mformat -i $@ -f 1440 ::
	mmd     -i $@    ::/EFI
	mmd     -i $@    ::/EFI/BOOT
	mcopy   -i $@ $< ::/EFI/BOOT

test_qemu: OVMF-pure-efi.fd
	qemu-system-x86_64 -L ./ -bios $< -net none

run: fat.img OVMF-pure-efi.fd
	qemu-system-x86_64 -L ./ -bios OVMF-pure-efi.fd -usb -usbdevice disk::fat.img

run_debug: OVMF-pure-efi.fd
	qemu-system-x86_64 -L ./ -bios $< -net none -serial tcp::666,server -s

connect:
	socat -,raw,echo=0 tcp4:localhost:666
	