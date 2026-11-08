/*
 * The real entry point for the bootloader.
 * This code runs first, sets up the machine state, and then calls the C main function.
 */

.set STACK_SEG, 0x0000
.set STACK_PTR, 0x7C00

.section .text.boot

.globl _start
.code16gcc     /* Tell the assembler we're in 16-bit real mode. */
_start:
    cli        /* Disable interrupts during setup. */

    /*
     * Set up a known segment state: the C code assumes a flat address space
     * where SS = DS = ES = 0. The BIOS guarantees none of these registers,
     * so we set all of them explicitly. The stack grows down from 0x7C00.
     */
    xor    %ax, %ax
    mov    %ax, %ss
    mov    $STACK_PTR, %esp /* C uses 32-bit stack offsets even in real mode. */
    mov    %ax, %ds
    mov    %ax, %es
    cld        /* C string operations require a cleared direction flag. */

    sti        /* Re-enable interrupts. */

    /*
     * The BIOS passes the number of the drive we were booted from in DL
     * (0x00 = first floppy, 0x80 = first hard disk). Save it before any
     * other code clobbers DX - we need it for our own disk reads later.
     */
    mov    %dl, boot_drive

    /* Now that the machine state is ready, call our C main function. */
    call   main

/* If main ever returns, hang the system. */
hang:
    jmp     hang

.section .data

.globl boot_drive
boot_drive:
    .byte  0x80
