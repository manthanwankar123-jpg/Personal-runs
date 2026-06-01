# mem_gcd — subtract GCD + JAL/JALR; stores @ 0x8000_0008
# Preload: a=66, b=99 @ 0 / 4  => gcd=33

.section .text
.globl _start
_start:
    lui   x5, 0x80000
    lw    x10, 0(x5)
    lw    x11, 4(x5)
    jal   x1, gcd
    sw    x10, 8(x5)
    ebreak

gcd:
    beq   x11, x0, gcd_done
    beq   x10, x0, gcd_a_zero
    blt   x10, x11, gcd_else
    sub   x10, x10, x11
    j     gcd
gcd_else:
    sub   x11, x11, x10
    j     gcd
gcd_a_zero:
    add   x10, x11, x0
gcd_done:
    jalr  x0, x1, 0
