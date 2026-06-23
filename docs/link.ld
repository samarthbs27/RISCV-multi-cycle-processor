/* Updated Linker script for RV32I */
/* Define the memory regions */
MEMORY
{
    rom (rx)  : ORIGIN = 0x00000000, LENGTH = 0x200   /* Instruction memory starts at 0x0, size 512 bytes */
    ram (rwx) : ORIGIN = 0x00000200, LENGTH = 0x200   /* Data memory starts at 0x200, size 512 bytes */
}

/* Entry point of the program */
ENTRY(_start)

/* Define the stack top */
_stack_start = 0x1FF;   /* Stack starts at 0x1FF */

/* Sections mapping */
SECTIONS
{
    /* Text section: contains the code */
    .text : {
        _text_start = .;
        KEEP(*(.text._start))    /* Ensure _start label is at the beginning of .text */
        *(.text*)                /* All other .text code */
        _text_end = .;
    } > rom

    /* Data section: initialized data */
    .data : {
        _data_start = .;
        *(.data*)
        _data_end = .;
    } > ram

    /* BSS section: uninitialized data */
    .bss : {
        _bss_start = .;
        *(.bss*)
        _bss_end = .;
    } > ram

    /* Stack: set up the stack pointer */
    .stack (NOLOAD) : {
        _stack_bottom = .;
        . = _stack_start;
        _stack_top = .;
    } > ram
}

