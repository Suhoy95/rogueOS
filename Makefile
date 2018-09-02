
CC := x86_64-w64-mingw32-gcc
CPPFLAGS := -I"../gnu-efi-3.0.8/inc/" \
			-I"../gnu-efi-3.0.8/inc/x86_64" \
			-I"../gnu-efi-3.0.8/inc/protocol"

main.efi: main.so
	objcopy -j .text                \
			-j .sdata               \
			-j .data                \
			-j .dynamic             \
			-j .dynsym              \
			-j .rel                 \
			-j .rela                \
			-j .reloc               \
			--target=efi-app-x86_64 \
			$<	                    \
			$@

main.so: main.o
	ld main.o                          \
	     /usr/lib/crt0-efi-x86_64.o    \
		-nostdlib                      \
		-znocombreloc                  \
		-T /usr/lib/elf_x86_64_efi.lds \
		-shared                        \
		-Bsymbolic                     \
		-L /usr/lib                    \
		-l:libgnuefi.a                 \
		-l:libefi.a                    \
		-o main.so

main.o: main.c
	gcc $^		                   \
		-c                         \
		-fno-stack-protector       \
		-fpic                      \
		-fshort-wchar              \
		-mno-red-zone              \
		-I /usr/include/efi        \
		-I /usr/include/efi/x86_64 \
		-DEFI_FUNCTION_WRAPPER     \
		-o $@

uefi.img: fat.img
	dd if=/dev/zero of=$@ bs=512 count=93750
	parted $@ -s -a minimal mklabel gpt
	parted $@ -s -a minimal mkpart EFI FAT16 2048s 93716s
	parted $@ -s -a minimal toggle 1 boot
	dd if=$< of=$@ bs=512 count=91669 seek=2048 conv=notrunc

fat.img: main.efi
	dd if=/dev/zero of=$@ bs=512 count=91669
	mformat -i $@ -h 32 -t 32 -n 64 -c 1
	mcopy   -i $@ $< ::

test_qemu: OVMF_CODE-pure-efi.fd OVMF_VARS-pure-efi.fd
	qemu-system-x86_64 -cpu qemu64 \
		-drive if=pflash,format=raw,unit=0,file=./OVMF_CODE-pure-efi.fd,readonly=on \
		-drive if=pflash,format=raw,unit=1,file=./OVMF_VARS-pure-efi.fd \
		-net none

run: uefi.img OVMF_CODE-pure-efi.fd OVMF_VARS-pure-efi.fd
	qemu-system-x86_64 -cpu qemu64\
		-drive if=pflash,format=raw,unit=0,file=./OVMF_CODE-pure-efi.fd,readonly=on \
		-drive if=pflash,format=raw,unit=1,file=./OVMF_VARS-pure-efi.fd \
		-drive file=$<,if=ide \
		-net none -serial tcp::666,server

connect:
	socat -,raw,echo=0 tcp4:localhost:666
