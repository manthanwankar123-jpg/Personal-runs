# mem_sum5 — sum five words @ 0x8000_0000; result in x11; then EBREAK
.section .text
.globl _start
_start:
    lui   x10, 0x80000      # x10 = 0x80000000
    addi  x11, x0, 0        # sum = 0
    addi  x12, x0, 5        # count = 5
loop:
    lw    x13, 0(x10)
    add   x11, x11, x13
    addi  x10, x10, 4
    addi  x12, x12, -1
    bne   x12, x0, loop
    ebreak
