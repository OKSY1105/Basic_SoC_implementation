MEMORY
{
   ps7_ocm_0 : ORIGIN = 0x00000000, LENGTH = 0x00030000
   ps7_ocm_1 : ORIGIN = 0xFFFF0000, LENGTH = 0x0000FE00
}

ENTRY(_start)

SECTIONS
{
   .text : {
       KEEP(*(.vectors))
       *(.text)
       *(.text.*)
       *(.rodata)
       *(.rodata.*)
   } > ps7_ocm_0

   .data : {
       *(.data)
       *(.data.*)
   } > ps7_ocm_0

   .bss : {
       *(.bss)
       *(.bss.*)
       *(COMMON)
   } > ps7_ocm_0

   /DISCARD/ : {
       *(.note.gnu.build-id)
       *(.ARM.attributes)
       *(.comment)
   }
}
