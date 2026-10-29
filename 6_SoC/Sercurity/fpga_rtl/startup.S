.section .vectors, "ax"
.global _vector_table
.global _start

_vector_table:
_start:
    /* 1. Mask all interrupts */
    cpsid if

    /* 2. Set Stack Pointer to top of OCM RAM */
    ldr sp, =0xFFFFE000

    /* 3. Jump straight to C main() */
    b main

    /* Infinite fallback loop */
hang:
    b hang
