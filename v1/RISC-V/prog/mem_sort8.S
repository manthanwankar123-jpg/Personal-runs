# mem_sort8 — in-place bubble sort of 8 words @ 0x8000_0000
# Preload (TB): 42, 7, 101, 3, 15, 8, 99, 1
# Golden: mem[0]=1, mem[28]=101, x11=sum=276

.section .text
.globl _start
_start:
    lui   x10, 0x80000      # base
    addi  x15, x0, 8        # n

outer_i:
    addi  x11, x0, 0        # i = 0
outer_test:
    addi  x17, x15, -1
    bge   x11, x17, sort_done

    addi  x12, x0, 0        # j = 0
inner_j:
    add   x18, x15, x0
    addi  x18, x18, -1
    sub   x18, x18, x11     # n - 1 - i
    bge   x12, x18, inner_done

    slli  x19, x12, 2
    add   x19, x10, x19
    lw    x13, 0(x19)
    lw    x14, 4(x19)
    blt   x14, x13, do_swap
    j     no_swap
do_swap:
    sw    x14, 0(x19)
    sw    x13, 4(x19)
no_swap:
    addi  x12, x12, 1
    j     inner_j

inner_done:
    addi  x11, x11, 1
    j     outer_test

sort_done:
    lw    x20, 0(x10)       # first
    lw    x21, 28(x10)      # last (offset 7*4)

    addi  x11, x0, 0        # sum
    addi  x12, x0, 0        # k
sum_loop:
    bge   x12, x15, sum_done
    slli  x19, x12, 2
    add   x19, x10, x19
    lw    x13, 0(x19)
    add   x11, x11, x13
    addi  x12, x12, 1
    j     sum_loop
sum_done:
    ebreak
