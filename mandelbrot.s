; vim: ft=nasm

%define MAX_ITERS 255

; graphics mode 13h
%define WIDTH  320
%define HEIGHT 200
%define FWIDTH  320.
%define FHEIGHT 200.

; register variables
%define c xmm6 ; complex coordinate
%define z xmm7 ; iterated variable

bits 16
org 0x7c00
	; set video mode
	mov ax, 13h
	int 10h

	; video memory segment
	push 0xa000
	pop es

	mov eax, cr0
	and ax, 0xFFFB ; clear coprocessor emulation cr0.EM
	or ax, 0x2     ; set coprocessor monitoring  cr0.MP
	mov cr0, eax
	; enable SSE
	mov eax, cr4
	or ax, 3<<9
	mov cr4, eax

init_palette:
	mov dx, 3c8h ; palette index port
	mov al, 0
	out dx, al
	mov dx, 3c9h ; palette data port
	times 3 out dx, al

	mov ecx, 0xff
	mov bl, 0
.color:
	mov al, cl
	out dx, al
	out dx, al
	add al, bl
	out dx, al
	inc bl
	loop .color

	; scaling factor
	movlps xmm0, [scale]
	divps  xmm0, [dim]
	movlps [scale], xmm0

draw:
	; loop over pixels
	mov ebx, HEIGHT*WIDTH-1
	mov ecx, HEIGHT

.rows:
	; convert pixel position to complex coords
	mov eax, WIDTH
	cvtsi2ss c, ecx
	unpcklps c, c
	cvtsi2ss c, eax

	mulps    c, [scale]
	subps    c, [offs]

	push ecx
	mov ecx, WIDTH
.cols:
	; z := c
	movaps z, c
	push ecx
	mov ecx, MAX_ITERS
.iter:
	; z := z*z + c
	xorps xmm0, xmm0
	movsd   xmm0, z
	shufps  z,    z,    14h ; z    =  a, b
	shufps  xmm0, xmm0, 60h ; xmm0 =  a, a
	movhlps xmm1, z         ; xmm1 =  b, a
	movhlps xmm2, xmm0      ; xmm2 = -b, b
	subss   xmm2, xmm1

	mulps   z,    xmm0      ; z    =  aa, ba
	mulps   xmm1, xmm2      ; xmm1 = -bb, ab
	addps   z,    xmm1      ; z = aa-bb, ab+ab
	addps   z,    c
	cvtss2si eax, z         ; break if abs(z) exceeds 4
	cmp eax, 4
	jge .putpixel
	loop .iter
.done:
	dec ebx
	subss c, [scale]
	pop ecx
	loop .cols
	pop ecx
	loop .rows

	hlt

.putpixel:
	add cl, 1
	mov [es:ebx], cl
	jmp .done
	ret

align 16
dim   dd FWIDTH, FHEIGHT, 0, 0
offs  dd 2., 1., 0, 0
scale dd 3., 2., 0, 0
start dd 1., 1., 0, 0
sto dq 0xffffffff

; padding and bootsector magic number
times 510-($-$$) db 0
dw 0xaa55
