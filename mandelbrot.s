; vim: ft=nasm

%use ifunc

; graphics mode 13h
%define WIDTH  320
%define HEIGHT 200

; user-defined
%define PALETTE_SIZE 16
%define MAX_ITERS    64

; auto-generated palette normalization
%define PALETTE_SHIFT (ilog2e(MAX_ITERS) - ilog2e(PALETTE_SIZE))

; register variables
%define z xmm6
%define c xmm7

bits 16
org 0x7c00
	; set video mode
	mov ax, 13h
	int 10h

	; video memory segment
	push 0xa000
	pop es

	; enable SSE
	; mov eax, cr0 ; disabling CPU exceptions unnecessary?
	; and ax, 0xfffb
	; or ax, 2
	; mov cr0, eax
	mov eax, cr4
	or ax, 1<<9 ; previously 3<<9, 2<<9 bit unnecessary?
	mov cr4, eax

	; init position multipliers
	mov eax, WIDTH/3
	mov ebx, HEIGHT/2
	cvtsi2ss xmm0, eax
	cvtsi2ss xmm1, ebx
	movss [mults.lo], xmm0
	movss [mults.hi], xmm1

init_palette:
	;mov dx, 0x3c6 ; palette mask
	;mov al, 0xff  ; mask all
	;out dx, al
	mov dx, 0x3c8 ; palette index port
	mov al, 0
	out dx, al

	mov dx, 0x3c9 ; palette data port
	out dx, al
	out dx, al
	out dx, al

	mov cx, 255
	mov bl, 0
.loop:
	mov al, bl
	out dx, al
	out dx, al

	or ax, cx
	out dx, al
	inc bl
	loop .loop

draw:
	; loop over pixels
	mov dword [x], WIDTH-1
.cols:
	mov dword [y], HEIGHT-1
.rows:
	; calculate c from screen position
	; c = a + bi
	; a = x /  (WIDTH/3) - 2
	; b = y / (HEIGHT/2) - 1
	cvtpi2ps c, [pos]
	divps    c, [mults]
	subps    c, [offs]

	; z := c
	movaps z, c
	xor ecx, ecx
.iter:
	; z := z*z + c
	xorps   xmm0, xmm0
	movlhps z,    xmm0
	movaps  xmm1, z
	shufps  z,    z,    00010100b ; z    =  a, b
	shufps  xmm1, xmm1, 01110000b ; xmm1 =  a, a
	movhlps xmm2, z               ; xmm2 =  b, a
	movhlps xmm3, xmm1            ; xmm3 = -b, b
	subss   xmm3, xmm2

	mulps   z,    xmm1            ; z    =  aa, ba
	mulps   xmm2, xmm3            ; xmm2 = -bb, ab

	addps   z,    xmm2            ; z = aa-bb, ab+ab
	addps   z,    c
	; break if abs(z) exceeds 4
	ucomiss z, [four]
	jz .pixel
	inc ecx
	cmp ecx, MAX_ITERS
	jl .iter
.done:
	dec dword [y]
	jge .rows
	dec dword [x]
	jge .cols

	hlt

.pixel:
	; normalize iterations to palette range
	;shr cx, PALETTE_SHIFT
	;or cl, 0x20 ; base offset in palette
	mov eax, WIDTH
	mov ebx, [y]
	mul ebx
	add eax, [x]
	mov [es:eax], cl
	jmp .done
	ret

align 8
mults:
.lo dd 0
.hi dd 0

offs:
.lo dd 2.0
.hi dd 1.0

; screen position
pos:
x dd 0
y dd 0

four dd 4.0

; padding and bootsector magic number
times 510-($-$$) db 0
dw 0xaa55
