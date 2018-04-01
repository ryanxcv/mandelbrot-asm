; vim: ft=nasm

%define MAX_ITERS 128

; graphics mode 13h
%define WIDTH  320
%define HEIGHT 200

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
	mov eax, cr4
	or ax, 1<<9
	mov cr4, eax

	; init position multipliers
	mov eax,  WIDTH/3
	mov ebx, HEIGHT/2
	cvtsi2ss xmm0, eax
	cvtsi2ss xmm1, ebx
	movss [mults.lo], xmm0
	movss [mults.hi], xmm1

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
	or  al, bl
	out dx, al
	inc bl
	loop .color

draw:
	; loop over pixels
	mov dword [x], WIDTH-1
.cols:
	mov dword [y], HEIGHT-1
.rows:
	; convert pixel position to complex coords
	cvtpi2ps c, [pos]
	divps    c, [mults]
	subps    c, [offs]

	; z := c
	movaps z, c
	mov cl, MAX_ITERS
.iter:
	; z := z*z + c
	xorps   xmm0, xmm0
	movlhps z,    xmm0
	movaps  xmm1, z
	shufps  z,    z,    14h ; z    =  a, b
	shufps  xmm1, xmm1, 70h ; xmm1 =  a, a
	movhlps xmm2, z         ; xmm2 =  b, a
	movhlps xmm3, xmm1      ; xmm3 = -b, b
	subss   xmm3, xmm2

	mulps   z,    xmm1      ; z    =  aa, ba
	mulps   xmm2, xmm3      ; xmm2 = -bb, ab

	addps   z,    xmm2      ; z = aa-bb, ab+ab
	addps   z,    c
	cvtss2si eax, z         ; break if abs(z) exceeds 5
	cmp eax, 4
	jge .pixel
	loop .iter
.done:
	dec dword [y]
	jge .rows
	dec dword [x]
	jge .cols
	hlt

.pixel:
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
	dd 2.
	dd 1.

; screen position
pos:
x dd 0
y dd 0

; padding and bootsector magic number
times 510-($-$$) db 0
dw 0xaa55
