amd64:
	cc -c -m32 -fno-pie -nostdinc -fno-builtin -fpack-struct -ffreestanding -fno-stack-protector -DCNT_SECT=16 -o amd64.o copy_obsd_show_head_amd64.S
	ld -nostdlib -Ttext 0 -x -N -s -Bstatic -e start -nopie -melf_i386 -o amd64.elf amd64.o
	objcopy -O binary amd64.elf amd64
arm64:
	cc -c -nostdinc -fno-builtin -fpack-struct -ffreestanding -fno-stack-protector -DCNT_SECT=16 -o arm64.o copy_obsd_show_head_arm64.S
	ld -nostdlib -T ldscript.arm64 -Bsymbolic -shared --pack-dyn-relocs=none --no-execute-only -o arm64.elf arm64.o
	objcopy -j .peheader -j .text -j .sdata -j .data -j .dynamic -j .dynsym -j .dynstr -j .rel -j .rel.dyn -j .rela -j .rela.dyn -j .reloc --output-target=binary arm64.elf arm64

