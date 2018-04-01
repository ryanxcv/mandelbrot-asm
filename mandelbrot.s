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
%define px edi ; screen pixel x
%define py esi ; screen pixel y

bits 16
org 0x7c00
	; set video mode
	mov ax, 13h
	int 10h

	; video memory segment
	push 0xa000
	pop es

	; enable SSE
	mov eax, cr4
	or ax, 1<<9
	mov cr4, eax

init_palette:
	mov dx, 3c8h ; palette index port
	mov al, 0
	out dx, al
	mov dx, 3c9h ; palette data port
	times 3 out dx, al

	mov cl, 0xff
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
	mov px, WIDTH
.cols:
	mov py, HEIGHT
.rows:
	; convert pixel position to complex coords
	cvtsi2ss c, py
	unpcklps c, c
	cvtsi2ss c, px
	mulps    c, [scale]
	subps    c, [offs]

	; z := c
	movaps z, c
	mov cl, MAX_ITERS
.iter:
	; z := z*z + c
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
	dec py
	jge .rows
	dec px
	jge .cols
	hlt

.putpixel:
	mov eax, WIDTH
	mul py
	add eax, px
	mov [es:eax], cl
	jmp .done
	ret

align 8
dim   dd FWIDTH, FHEIGHT
offs  dd 2., 1.
scale dd 3., 2., 0, 0

; padding and bootsector magic number
times 510-($-$$) db 0
dw 0xaa55
