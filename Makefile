amd64:
	cc -c -m32 -fno-pie -nostdinc -fno-builtin -fpack-struct -ffreestanding -fno-stack-protector -DCNT_SECT=16 -o amd64.o copy_obsd_show_head_amd64.S
	ld -nostdlib -Ttext 0 -x -N -s -Bstatic -e start -nopie -melf_i386 -o amd64.elf amd64.o
	objcopy -O binary amd64.elf amd64

