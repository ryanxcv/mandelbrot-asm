; vim: ft=nasm

%define MAX_ITERS 255

; graphics mode 13h
%define WIDTH  320
%define HEIGHT 200
%define FWIDTH  320.
%define FHEIGHT 200.

; register variables
%define ca xmm4 ; complex coordinate
%define cb xmm5
%define za xmm6 ; iterated variable
%define zb xmm7

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
	times 2 out dx, al
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
	cvtsi2ss ca, eax
	cvtsi2ss xmm0, ecx
	movlhps  ca, xmm0
	mulps    ca, [scale]
	subps    ca, [offs]
	movhlps  cb, ca

	push ecx
	mov ecx, WIDTH
.cols:
	; z := c
	movss za, ca
	movss zb, cb
	push ecx
	mov ecx, MAX_ITERS
.iter:
	; z := z*z + c
	movss xmm0, zb
	mulss zb,   za
	addss zb,   zb   ; b = 2ab
	mulss za,   za
	mulss xmm0, xmm0
	subss za,   xmm0 ; a = a^2 - b^2

	;movlhps za, zb
	;mulss   zb, za
	;addss   zb, zb   ; b = 2ab
	;mulps   za, za
	;movhlps xmm0, za
	;subss   za, xmm0 ; a = a^2 - b^2

	addss za, ca
	addss zb, cb

	ucomiss za, [four] ; break if abs(z) exceeds 4
	ja .putpixel
	loop .iter
.done:
	dec ebx
	subss ca, [scale.a]
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
dim  dd FWIDTH, 1., FHEIGHT, 1.
offs dd 2., 0, 1., 0
scale:
.a   dd 3., 0, 2., 0
four dd 4.

; padding and bootsector magic number
times 510-($-$$) db 0
dw 0xaa55
