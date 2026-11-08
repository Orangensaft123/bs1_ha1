/*
 * Linker script for a 16-bit real-mode bootloader.
 *
 * This script arranges the output binary to be compliant with the BIOS boot
 * specification. The BIOS loads the first 512 bytes of a bootable disk into
 * memory at address 0x7C00 and begins execution there.
 */

/*
 * The ENTRY command sets the execution entry point. The program will start
 * running at the '_start' symbol, which is defined in the 'boot.s' file.
 */
ENTRY(_start);

/*
 * The PHDRS command declares the program headers (segments) explicitly. We
 * link with --nmagic, which turns off page alignment so that the tiny binary
 * stays contiguous. Without explicit segments, the linker then packs code and
 * writable data into one segment that is readable, writable AND executable,
 * and newer binutils (>= 2.39) warn about that. With three segments - code
 * (R X), data (RW) and the boot signature (R) - the layout of the output is
 * unchanged but every section has proper permissions.
 */
PHDRS
{
    text PT_LOAD FLAGS(5); /* R X */
    data PT_LOAD FLAGS(6); /* RW  */
    sig  PT_LOAD FLAGS(4); /* R   */
}

SECTIONS
{
    /*
     * Set the starting address for all subsequent sections to 0x7C00.
     * This is the memory location where the BIOS loads our bootloader.
     * The '.' symbol is the location counter, which the linker advances as
     * it lays out sections.
     */
    . = 0x7C00;

    /*
     * The .text section contains all our executable code.
     * 'AT(0x7C00)' specifies the "load memory address" (LMA), ensuring the
     * final binary is structured to be loaded at 0x7C00.
     */
    .text : AT(0x7C00)
    {
        /*
         * We explicitly place our custom '.text.boot' section first. This contains
         * the _start code from boot.s, guaranteeing it's at the very beginning.
         */
        *(.text.boot);
        
        /*
         * Next, include all other code sections. The wildcard also catches
         * compiler-generated variants like '.text.startup' (gcc places main
         * there at -Os); without it those sections would only be placed by
         * the linker's orphan handling, which we don't want to rely on.
         */
        *(.text);
        *(.text.*);

        /*
         * It's common practice to place read-only data, like string literals,
         * right after the code. They are part of the same logical segment.
         */
        *(.rodata*);
    } :text

    /*
     * The .data section contains initialized global and static variables.
     * For a simple bootloader, this is often empty but is good practice to include.
     */
    .data :
    {
        *(.data);
    } :data

    /*
     * The .bss section is for uninitialized global and static variables.
     * The linker reserves space for them, but they don't take up space in the
     * final binary file itself.
     */
    .bss :
    {
        *(.bss);
        *(COMMON);
    } :data

    /*
     * The .sig section is a custom section to place the magic boot signature.
     * 'AT(0x7DFE)' forces this section to be located at byte offset 510 in the
     * final binary, which is exactly where the BIOS expects to see it.
     * 0x7C00 (start) + 510 = 0x7DFE.
     */
    .sig : AT(0x7DFE)
    {
        SHORT(0xAA55); /* The required 2-byte boot signature. */
    } :sig
    
    /*
     * This section adds metadata to the ELF file to indicate that the stack
     * should not be executable. While not strictly necessary for our simple
     * bootloader, it's good practice and resolves linker warnings.
     * (NOLOAD) ensures it's only metadata and not loaded into memory.
     */
    .note.GNU-stack (NOLOAD) : {}

    /*
     * The /DISCARD/ directive tells the linker to throw away sections that are
     * not needed in our final binary, such as debugging info, comments, etc.
     * This helps keep the final bootloader file small and clean.
     */
    /DISCARD/ :
    {
        *(.note*);
        *(.iplt*);
        *(.igot*);
        *(.rel*);
        *(.comment);
        *(.eh_frame);
    }
}
