; vim: ft=nasm

%define MAX_ITERS 255

; graphics mode 13h
%define WIDTH  320
%define HEIGHT 200

; register variables
%define pos ebx
%define x   esi
%define y   edi
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

	; enable SSE
	mov eax, cr0
	and ax, 0xfffb ; clear coprocessor emulation cr0.EM
	or ax, 10b     ; set coprocessor monitoring  cr0.MP
	mov cr0, eax
	mov eax, cr4
	or ax, 11b<<9
	mov cr4, eax

init_palette:
	mov dx, 3c8h ; palette index port
	xor al, al
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

	; loop over pixels
	mov pos, HEIGHT*WIDTH-1
	mov y, HEIGHT
	movss cb, [maxb]
loop_y:
	mov x, WIDTH
	movss ca, [maxa]
loop_x:
	; z := c
	movss za, ca
	movss zb, cb
	mov ecx, MAX_ITERS

.iter:
	; z := z*z + c
	movss xmm0, zb
	mulss xmm0, xmm0
	mulss zb, za
	addss zb, zb   ; b = 2ab
	mulss za, za
	subss za, xmm0 ; a = a^2 - b^2

	addss za, ca
	addss zb, cb

	ucomiss za, [limit]
	jae .draw
	loop .iter
.done:
	dec pos
	subss ca, [pixsz]
	dec x
	jnz loop_x
	subss cb, [pixsz]
	dec y
	jnz loop_y

	hlt

.draw:
	add cl, 128
	mov [es:ebx], cl
	jmp .done
	ret

maxa:
maxb  dd 1.
pixsz dd 0.01 ; coordheight / screenheight = 2 / 200
limit dd 4.

; padding and bootsector magic number
times 510-($-$$) db 0
dw 0xaa55
