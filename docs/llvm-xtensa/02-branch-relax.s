	.text
	.global f
f:
	entry a1, 32
	beqi a8, 5, far
	.rept 200
	l32i a9, a2, 0
	.endr
far:
	retw
