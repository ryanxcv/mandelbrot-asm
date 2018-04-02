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
	movaps xmm0, [scale]
	divps  xmm0, [dim]
	movaps [scale], xmm0

draw:
	; loop over pixels
	mov ebx, HEIGHT*WIDTH-1
	mov ecx, HEIGHT

.rows:
	; convert pixel position to complex coords
	mov eax, WIDTH
	cvtsi2ss c, ecx
	movlhps  c, c
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
	movhlps xmm0, z
	mulss   xmm0, z
	addss   xmm0, xmm0 ; xmm0 = 2ab
	mulps   z, z
	movhlps xmm1, z
	subps   z, xmm1    ; z = a^2 - b^2
	movlhps z, xmm0
	addps   z, c

	ucomiss z, [four]       ; break if abs(z) exceeds 4
	ja .putpixel
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
dim   dd FWIDTH, 1., FHEIGHT, 1.
offs  dd 2., 0, 1., 0
scale dd 3., 0
.y    dd 2., 0
four  dd 4.

; padding and bootsector magic number
times 510-($-$$) db 0
dw 0xaa55
