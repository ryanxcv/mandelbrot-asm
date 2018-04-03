default: qemu
b: bochs
bochs: bochssrc.txt boot.bin
	bochs -f $<
q: qemu
qemu: boot.bin
	qemu-system-x86_64 $<
boot.bin: mandelbrot.s check.s
	nasm -f bin -o $@ $<
objdump: boot.bin
	objdump -D -m i386 -M addr16,data16 -b binary $<
