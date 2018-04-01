qemu: boot.bin
	qemu-system-x86_64 $<
boot.bin: mandelbrot.s
	nasm -f bin -o $@ $<
objdump: boot.bin
	objdump -D -m i386 -b binary $<
