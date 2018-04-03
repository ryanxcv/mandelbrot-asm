	; check if in cardioid
	xorps xmm2, xmm2
	mov eax, 1
	movss xmm3, xmm2 ; xmm3 = 1
	cvtsi2ss xmm2, eax
	mov eax, 4
	cvtsi2ss xmm1, eax
	divss xmm2, xmm1 ; xmm2 = 1/4

	movss xmm0, ca
	subss xmm0, xmm2
	mulss xmm0, xmm0
	movss xmm1, cb
	mulss xmm1, xmm1
	addss xmm0, xmm1
	sqrtss xmm0, xmm0 ; xmm0 = p = sqrt((x - 1/4)^2 + y^2)

	movss xmm1, xmm0
	mulss xmm1, xmm1
	addss xmm1, xmm1
	subss xmm0, xmm1
	addss xmm0, xmm2 ; xmm0 = p - 2p^2 + 1/4

	comiss ca, xmm0
	jb .done

	; check if in bulb
	movss xmm0, ca
	addss xmm0, xmm3
	mulss xmm0, xmm0 ; xmm0 = (x+1)^2

	movss xmm1, cb
	mulss xmm1, xmm1 ; xmm1 = y^2

	mulss xmm2, xmm2 ; xmm2 = 1/16

	addss xmm0, xmm1 ; xmm0 = (x+1)^2 + y^2

	comiss xmm0, xmm2
	jb .done
