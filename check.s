	; check if in cardioid
	movss   xmm0, ca
	movss   xmm1, [one]
	divss   xmm1, [four]
	subss   xmm0, xmm1 ; xmm0 = x - 1/4
	movlhps xmm0, xmm0 ; store for later

	movss   xmm1, cb
	mulss   xmm0, xmm0
	mulss   xmm1, xmm1 ; xmm1 = y^2
	movlhps xmm1, xmm1 ; store for later
	addss   xmm1, xmm0 ; xmm1 = q = (x - 1/4)^2 + y^2

	movhlps xmm0, xmm0 ; restore xmm0 = x - 1/4
	addss xmm0, xmm1
	mulss xmm0, xmm1   ; xmm0 = q(q + (x - 1/4))

	movhlps xmm1, xmm1 ; restore xmm1 = y^2
	divss xmm1, [four] ; xmm1 = 1/4 y^2

	comiss xmm0, xmm1
	jb  .done

	; check if in bulb
	movss xmm0, ca
	addss xmm0, [one]
	mulss xmm0, xmm0 ; xmm0 = (x+1)^2

	movss xmm1, cb
	mulss xmm1, xmm1 ; xmm1 = y^2

	movss xmm2, [one]
	divss xmm2, [four]
	mulss xmm2, xmm2 ; xmm2 = 1/16

	addss xmm0, xmm1 ; xmm0 = (x+1)^2 + y^2

	comiss xmm0, xmm2
	jb .done
