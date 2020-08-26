# Lab 1 - Booting a PC

## 0. Software Setup

The lab must use an x86 Athena machine:
```sh
$ uname -a
(i386 GNU/Linux or i686 GNU/Linux or x86_64 GNU/Linux)
```

If having a non-Athena machine, we need to install **QEMU** (an x86 emulator for running the kernel) and possibly **GCC** (a compiler toolchain including assembler, liner, C compiler and debugger for compiling and testing the kernel) following the instructions on the [tool page](https://pdos.csail.mit.edu/6.828/2018/tools.html). My machine is a **MacOS**, and here are the instructions:

### QEMU

1. Install developer tools on MacOS:
`$ xcode-select --install`

2. Install the QEMU dependencies from homebrew. But don't install qemu itself because we need the 6.828 patched version:
`$ brew install $(brew deps qemu)`

3. Build 6.828 patched QEMU:
    - Clone the 6.828 QEMU repo.
    `$ git clone https://github.com/mit-pdos/6.828-qemu.git labs/qemu`
    - Configure the source code. If not specifying the `--prefix`, the QEMU will be installed to `/usr/local` by default.
    `$ ./configure --disable-kvm --disable-werror --disable-sdl --prefix=[INSTALL_DESTINATION] --target-list="i386-softmmu x86_64-softmmu"`
    - Build the QEMU binary.
    `$ make`
    - Install the QEMU binary. The gettext utility doesn't add installed binaries to the PATH, so we need to run:
    `$ PATH=${PATH}:/usr/local/opt/gettext/bin make install`

### GCC

We can choose to install the i386-jos-elf-* toolchain from the Homebrew otherwise kernel cannot be built.
```sh
$ brew tap liudangyi/i386-jos-elf-gcc
$ brew install i386-jos-elf-gcc i386-jos-elf-gdb
```

Or, we can build our own compiler toolchain by following the [tool page](https://pdos.csail.mit.edu/6.828/2018/tools.html).





## 1. PC Bootstrap

The purpose of the first exercise is to introduce the x86 assembly language and PC bootstrap process. Also, it gets us familiar with QEMU and GDB debugging.

### Getting started with x86 assembly

[PC Assembly Language](../../resources/pc-asm-book.pdf) is an excellent place to start. But it's written for NASM assembler (*Intel* syntax) while we will use GNU assembler (*AT&T* syntax). Luckily the conversion between the two syntaxes is simply convered in [Brennan's Guide to Inline Assembly](http://www.delorie.com/djgpp/doc/brennan/brennan_att_inline_djgpp.html)

The definitive reference for x86 assembly language programming is Intel's instruction set architecture reference: 1) old but short and we will use [80386 Programmer's Reference Manual](https://pdos.csail.mit.edu/6.828/2018/readings/i386/toc.htm); 2) latest and full [IA-32 Intel Architecture Software Developer's Manuals](https://software.intel.com/content/www/us/en/develop/articles/intel-sdm.html).

### Simulating the x86

Using the QEMU emulator simplifies the debugging, e.g. we can set break points inside of the emulated x86 which is difficult to to with the silicon version of x86.

Check out the Lab 1 source code and build the minimal 6.828 boot loader and kernel.
```sh
$ git clone https://pdos.csail.mit.edu/6.828/2018/jos.git labs/lab01-boot-pc
$ cd labs/lab01-boot-pc
$ make
```

Now we have the "virtual hard disk" of an emulated x86 `obj/kern/kernel.img`, which contains both boot loader `obj/boot/boot` and kernel `obj/kern`. Start the QEMU with only the serial console:
```sh
$ make qemu-nox
... ...
Welcome to the JOS kernel monitor!
Type 'help' for a list of commands.
K> help
help - Display this list of commands
kerninfo - Display information about the kernel
K> kerninfo
Special kernel symbols:
  _start                  0010000c (phys)
  entry  f010000c (virt)  0010000c (phys)
  etext  f010178e (virt)  0010178e (phys)
  edata  f0119300 (virt)  00119300 (phys)
  end    f0119940 (virt)  00119940 (phys)
Kernel executable memory footprint: 103KB
```

### PC's Address Space

```
+------------------+  <- 0xFFFFFFFF (4GB)
|      32-bit      |
|  memory mapped   |
|     devices      |
|                  |
/\/\/\/\/\/\/\/\/\/\
/\/\/\/\/\/\/\/\/\/\
|                  |
|      Unused      |
|                  |
+------------------+  <- depends on amount of RAM
|                  |
| Extended Memory  |
|                  |
+------------------+  <- 0x00100000 (1MB)
|     BIOS ROM     |
+------------------+  <- 0x000F0000 (960KB)
|  16-bit devices, |
|  expansion ROMs  |
+------------------+  <- 0x000C0000 (768KB)
|   VGA Display    |
+------------------+  <- 0x000A0000 (640KB)
|                  |
|    Low Memory    |
|                  |
+------------------+  <- 0x00000000
```

#### 0x00000000 ~ 0x0009FFFF (640KB): Low Memory

#### 0x000A0000 ~ 0x000FFFFF (384KB): Reserved by Hardware

For special usages, such as video display buffers, firmware held in non-volatile memory. The most important part of this reserved area is the Basic Input/Output System (BIOS). BIOS occupied 64KB region from 0x000F0000 to 0x000FFFFF, which is responsible for performing basice system initialization and loading the OS from some appropriate location.

#### 0x00100000 ~ RAM Size: Extended Memory

Modern PCs supports 4GB physical address spaces or more but nevertheless preserved the early PCs' layout of low 1MB in order to ensure backward compatibility with existing software. Therefore, a "hole" from 0x000A0000 to 0x000FFFFF divides the RAM into *low memory* and *extended memory*.

### ROM BIOS

#### Functions
- Set up interrupt descriptor table
- Initialize the VGA disaply, PCI bus and all important devices that BIOS knows
- Search the bootable device, read and transfer control to the boot loader

#### The very first instruction

Open one terminal and start the QEMU with GDB. QEMU stops before the processor executes the first instruction and waits for a debugging connection from GDB.
```sh
$ make qemu-nox-gdb
***
*** Now run 'make gdb'.
***
qemu-system-i386 -nographic -drive file=obj/kern/kernel.img,index=0,media=disk,format=raw -serial mon:stdio -gdb tcp::25501 -D qemu.log  -S
```

Course provides the `.gdbinit` that sets up GDB to debug the 16-bit code used during early boot and directed it to attach to the listening QEMU. Open another terminal and run GDB. But I got the following error.
```sh
$ make gdb
gdb -n -x .gdbinit
make: gdb: No such file or directory
make: *** [gdb] Error 1
```

It is because the GDB installed in the *Section 0. Software Setup* is `i386-jos-elf-gdb` under `/usr/local/bin`. Therefore, run GDB like this.
```sh
$ i386-jos-elf-gdb
GNU gdb (GDB) 7.3.1
This GDB was configured as "--host=x86_64-apple-darwin19.6.0 --target=i386-jos-elf".
+ target remote localhost:25501
The target architecture is assumed to be i8086
[f000:fff0]    0xffff0:	ljmp   $0xf000,$0xe05b
0x0000fff0 in ?? ()
+ symbol-file obj/kern/kernel
```

The line to be executed describes: now at physical address `0xffff0` (top of the BIOS ROM), the instruction to execute is `ljmp`, jumping to the Code Segment (CS) `0xf000` and Instruction Pointer (IP) `0xe05b`.

Real mode addressing [CS:IP] could be translated to a physical address by the formula: *physical address = 16 * segment(CS) + offset(IP)*. For example, `16 * 0xf000 + 0xfff0 = 0xffff0`.





## 2. Boot Loader

### Boot loader procedure

Hard disks for PC are divided into *512 byte* region called *sectors*. A *sector* is the hard disk's minimum granularity: each read/write operation must be one or more sectors in size and aligned on a sector boundary. If a disk is bootable, the first sector is called boot sector where the boot loader code resides.

BIOS finds the hard disk and loads the boot sector into memory at physical address `0x7c00`, then `jmp` to CS:IP `0000:7c00`, passing control to the boot loader.

The boot loader source files are *boot/boot.S* and *boot/main.c*. The disassembly of the boot loader after compilation is *obj/boot/boot.asm*, in which it tells the code layout in physical memory. Boot loader performs two main tasks:
1. Switch from real mode to 32-bit protected mode so that software can access memory above 1MB. It's described in the Section 1.2.7 and 1.2.8 of [PC Assembly Language](../../resources/pc-asm-book.pdf). Now the physical address translation of [CS:IP] will be 32 bits instead of 16.
2. Read kernel from the hard disk by directly accessing the IDE disk device registers via x86's special I/O instructions.

#### Exercise 3

1. At what point does the processor start executing 32-bit code? What exactly causes the switch from 16- to 32-bit mode?

`ljmp   $PROT_MODE_CSEG, $protcse` in the *boot/boot.S*.

2. What is the last instruction of the boot loader executed?

`((void (*)(void)) (ELFHDR->e_entry))()` in C or `7d63:	ff 15 18 00 01 00    	call   *0x10018` in disassembly as shown in the *obj/boot/boot.asm*.

3. Where is the first instruction of the kernel?

Set a break point at the last boot loader instruction and continue to that instruction. Step one instruction further and we reach the first kernel instruction `0x10000c:	movw   $0x1234,0x472`.

```
(gdb) b *0x7d63
(gdb) c
Continuing.
The target architecture is assumed to be i386
=> 0x7d63:	call   *0x10018
Breakpoint 1, 0x00007d63 in ?? ()
(gdb) si
=> 0x10000c:	movw   $0x1234,0x472
0x0010000c in ?? ()
(gdb) x/2i
   0x100015:	mov    $0x117000,%eax
   0x10001a:	mov    %eax,%cr3
```

4. How does the boot loader decide how many sectors it must read in order to fetch the entire kernel from disk? Where does it find this information?

Boot loader gets the **program header table** and **number of entries** from ELF header `ELFHDR + ELFHDR->e_phoff` and `ELFHDR->e_phnum` respectively.

```c
ph = (struct Proghdr *) ((uint8_t *) ELFHDR + ELFHDR->e_phoff);
eph = ph + ELFHDR->e_phnum;
for (; ph < eph; ph++)
	readseg(ph->p_pa, ph->p_memsz, ph->p_offset);
```

### Loading the kernel

The C source file (.c) is compiled into an object file (.o) containing assembly instructions encoded in the binary format. The object files are combined into a single binary in the ELF format, which stands for *Executable and Linkable Format*. Full information of ELF format is available in the [ELF Specification](../../resources/elf-spec.pdf). The [Wiki Page](https://en.wikipedia.org/wiki/Executable_and_Linkable_Format) has a short description.

The ELF binary starts with a fixed-length *ELF header* (*inc/elf.h*), followed by a variable-length *program header* listing each of the program sections to be loaded.

```
$ i386-jos-elf-objdump -x obj/boot/boot.out

obj/boot/boot.out:     file format elf32-i386
obj/boot/boot.out
architecture: i386, flags 0x00000012:
EXEC_P, HAS_SYMS
start address 0x00007c00

Program Header:
    LOAD off    0x00000054 vaddr 0x00007c00 paddr 0x00007c00 align 2**2
         filesz 0x0000024c memsz 0x0000024c flags rwx

Sections:
Idx Name          Size      VMA       LMA       File off  Algn
  0 .text         0000017e  00007c00  00007c00  00000054  2**2
                  CONTENTS, ALLOC, LOAD, CODE
  1 .eh_frame     000000cc  00007d80  00007d80  000001d4  2**2
                  CONTENTS, ALLOC, LOAD, READONLY, DATA
  2 .stab         000006d8  00000000  00000000  000002a0  2**2
                  CONTENTS, READONLY, DEBUGGING
  3 .stabstr      000007df  00000000  00000000  00000978  2**0
                  CONTENTS, READONLY, DEBUGGING
  4 .comment      00000011  00000000  00000000  00001157  2**0
                  CONTENTS, READONLY
SYMBOL TABLE:
00007c00 l    d  .text	00000000 .text
00007d80 l    d  .eh_frame	00000000 .eh_frame
... ...
```

“VMA" (link address) of a section is the memory address form which the section expects to execute. "LMA" (load address) is the address at which that section should be loaded into memory. We find the `VMA=LMA=0x7c00`, so that BIOS loads the boot into memory starting at `0x7c00` and boot executes from that address, too. This is verified in the beiginning of the Section 2. The correct link address is set in the generated code by passing `-Ttext 0x7c00` to the linker in the *boot/Makefrag*.

One field in the ELF header is also important, `e_entry` (*inc/elf.h*). It holds the link address of the *entry point* in the program, where the program should begin executing. Look at the Exercise 3.3, the boot load jumps to the `0x10000c` kernel's entry point.

```
$ i386-jos-elf-objdump -f obj/kern/kernel

obj/kern/kernel:     file format elf32-i386
architecture: i386, flags 0x00000112:
EXEC_P, HAS_SYMS, D_PAGED
start address 0x0010000c
```





## 3. Kernel

### Using virtual memory to work around position dependence

Unlike boot load, the link address and load address are different for kernel. OS kernel often like to be linked and run at high *virtual address (VA)*, e.g. `0xf0100000`, in order to leave the lower part of processor's VA space for user programs to use.

But many machines don't have any physical memory at that high address. So memory management unit (MMU) is employed to map virtual address `0xf0100000` (VMA) to physical address `0x00100000` (LMA).

```
$ i386-jos-elf-objdump -h obj/kern/kernel

obj/kern/kernel:     file format elf32-i386
Sections:
Idx Name          Size      VMA       LMA       File off  Algn
  0 .text         0000178e  f0100000  00100000  00001000  2**2
                  CONTENTS, ALLOC, LOAD, READONLY, CODE
```

For now, we just map the first 4MB of physical memory by using the statically-initialized page directory and page table in *kern/entrypgdir.c*. Once the `CR0_PG` is set in the *kern/entry.S*, memory references are VAs. Before that, they are physical addresses. `entry_pgdir` in the *kern/entrypgdir.c* translates the VA in the ranges of [0x00000000, 0x00400000] and [0xf0000000, 0xf0400000] to physical address [0x00000000, 0x00400000]. Access to the VA not in the two ranges will cause a hardware exception.

#### Exercise 7

1. Use QEMU and GDB to trace into the JOS kernel and stop at the `movl %eax, %cr0`. Examine memory at `0x00100000` and at `0xf0100000`. Now, single step over that instruction and examine memory at `0x00100000` and at `0xf0100000` again.

From *obj/kern/kernel.asm* we know that instruction should be placed at `0x00100025` before the VA is turned on. So set the breakpoint to that address.

```
(gdb) b *0x100025
Breakpoint 1 at 0x100025
(gdb) c
Continuing.
The target architecture is assumed to be i386
=> 0x100025:	mov    %eax,%cr0
Breakpoint 1, 0x00100025 in ?? ()
(gdb) x/8w 0xf0100000
0xf0100000:	0x00000000	0x00000000	0x00000000	0x00000000
0xf0100010:	0x00000000	0x00000000	0x00000000	0x00000000
(gdb) x/8w 0x00100000
0x100000:	0x1badb002	0x00000000	0xe4524ffe	0x7205c766
0x100010:	0x34000004	0x7000b812	0x220f0011	0xc0200fd8

(gdb) si
=> 0x100028:	mov    $0xf010002f,%eax
0x00100028 in ?? ()
(gdb) x/8w 0xf0100000
0xf0100000:	0x1badb002	0x00000000	0xe4524ffe	0x7205c766
0xf0100010:	0x34000004	0x7000b812	0x220f0011	0xc0200fd8
(gdb) x/8w 0x00100000
0x100000:	0x1badb002	0x00000000	0xe4524ffe	0x7205c766
0x100010:	0x34000004	0x7000b812	0x220f0011	0xc0200fd8
```

2. What is the first instruction after the new mapping is established that would fail to work properly if the mapping weren't in place?

The first instruction would fail is `jmp *%eax` because that VA is out of boundary if mapping weren't in place.

```
### obj/kern/kernel.asm ###
# Now paging is enabled, but we're still running at a low EIP
# Jump up above KERNBASE before entering C code.
	mov	$relocated, %eax
f0100028:	b8 2f 00 10 f0       	mov    $0xf010002f,%eax
	jmp	*%eax
f010002d:	ff e0                	jmp    *%ea
```

### Formatted printing to the console

Three source files related to the formatted printing: *kern/printf.c*, *lib/printfmt.c*, *kern/console.c*.

#### Exercise 8

0. Finish the code for printing octal numbers using "%o" in the *lib/printfm.c*.

With the following code, kernel starts with `6828 decimal is 015254 octal!` message because of `cprintf("6828 decimal is %o octal!\n", 6828);` in the `i386_init()`.

```c
// (unsigned) octal
case 'o':
  putch('0', putdat);
  num = getuint(&ap, lflag);
  base = 8;
  goto number;
```

1. Explain the interface between *printf.c* and *console.c*. Specifically, what function does *console.c* export? How is this function used by *printf.c*?

*printf.c* uses `cputchar()` from *console.c* to make `putch()` function. And `putch()` is passed into `vprintfmt()` in the *printfmt.c*.

2.  Explain the following code from *console.c*.

`crt_buf` is initialized to the display I/O memory in the `cga_init()`.

```c
// If screen is full, scroll down CRT_COLS characters
if (crt_pos >= CRT_SIZE) {
  int i;
  // Push out CRT_COLS of data from the beginning of the display buffer
  memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
  // Erase the previous characters at the end
  for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
    crt_buf[i] = 0x0700 | ' ';
  // Move position back to the current end
  crt_pos -= CRT_COLS;
}
```

3. In the call to `cprintf()`, what does `fmt` and `ap` point to in the following code?

`fmt` points to the formatted string. `ap` points to the argument list.

```c
int x = 1, y = 3, z = 4;
cprintf("x %d, y %x, z %d\n", x, y, z);
```

4. What is the output of the following code on the little-endian x86 machine?

`57616` in hex format is `e110`. On little-endian machine, `i` is stored as `0x72`, `0x6c`, `0x64`, `0x00`, which are `rld\0`.

```c
unsigned int i = 0x00646c72;
cprintf("H%x Wo%s", 57616, &i);
```

5. What is going to be printed for `z` in the following code?

Add the following to the `i386_init()` after the console initialization, build the kernel and start the GDB. From the *kernel.asm*, we know the arguments of `cprintf()` are pushed onto stack from right to left, i.e. 0x04 -> 0x03 -> formatted string.

```c
/* kern/init.c - i386_init() */
cprintf("x=%d y=%d z=%d", 3, 4);

/* obj/kern/kernel.asm */
f01000de:	c7 44 24 08 04 00 00 	movl   $0x4,0x8(%esp)
f01000e5:	00 
f01000e6:	c7 44 24 04 03 00 00 	movl   $0x3,0x4(%esp)
f01000ed:	00 
f01000ee:	c7 04 24 12 18 10 f0 	movl   $0xf0101812,(%esp)
f01000f5:	e8 00 08 00 00       	call   f01008fa <cprintf>
```

Examining the argument list `ap`, `0x03` is at a lower address compared to `0x04` because stack grows downwards. The pop-out sequence is from the lower end, i.e. 0x03 -> 0x04 -> 0x00. Therefore, `z=0` will be print out. Note that the content is unknown, not always zero.

```
(gdb) si
=> 0xf01008c7 <vcprintf>:	push   %ebp
vcprintf (fmt=0xf0101812 "x=%d y=%d z=%d\n", ap=0xf0116fe4 "\003")

(gdb) x/s 0xf0101812
0xf0101812:	 "x=%d y=%d z=%d\n"
(gdb) x/4w 0xf0116fe4
0xf0116fe4:	0x00000003	0x00000004	0x00000000	0x00000000
```

6. Let's say that GCC changed its calling convention so that it pushed arguments on the stack in declaration order, so that the last argument is pushed last. How would you have to change cprintf or its interface so that it would still be possible to pass it a variable number of arguments?

Probably we can pass in another argument indicating the number of arguments, thus it is possible to find the memory address of `fmt`.

#### Challenge: color print

According to the [ANSI Codes](http://rrbrandt.dee.ufcg.edu.br/en/docs/ansi/), setting graphics mode follows the syntax `ESC[Ps1;Ps2;...PsNm]`, where

**ESC**: ASCII escape character 27(dec)/033(oct)/1B(hex);
**PsX**: text attributes and color codes;

```c
/* kern/init.c - i386_init() */
/* 0 (all off), 1 (bold), 4 (underscore), 31 (red foreground), 43 (yellow background) */
cprintf("Lab1-Ch: \033[1;4;31;43mHello colorful world! \033[0m\n");
```





## The Stack

### Stack pointer `esp`

The x86 stack pointer points to the lowest memory address of the stack (top of the stack) that is currently in use. The growth of stack towards the lower address. In 32-bit mode, the stack holds 32-bit value, `esp` is always divisible by 4.

- Push a value onto the stack
Stack pointer decreases, write the value to the address that stack pointer currently pointing to, i.e. `*--esp=value`.

- Pop a value from stack
Read the value from the address that stack pointer pointing to, increase the stack pointer, i.e. `value=*esp++`.

### Base pointer `ebp`

Base pointer is used to reference all the function arguments and variables in the current stack frame. At the beginning of a subroutine, the previous function's base pointer is save by pushing `ebp` onto the stack, and then copies the current `esp` value into `ebp` during the current function execution. Thus, it's possible to trace back through the stack by following the chain of saved `ebp`, to determine the nested sequence of function calls.

### Instruction pointer `eip`

Function's return instruction pointer holds the address of the next CPU instruction to execute, and it's saved onto the stack as part of the `call` instruction.

#### Exercise 9

1. Determine where the kernel initializes its stack, and exactly where in memory its stack is located. How does the kernel reserve space for its stack? And at which "end" of this reserved area is the stack pointer initialized to point to?

Stack is set at `movl $(bootstacktop),%esp` in the *kern/entry.S*. The kernel stack region is [bootstack, bootstacktop], i.e. [0xf0110000, 0xf011800]. It's reserved in the data segment by declaring the `bootstack` and `bootstacktop` in the *kern/entry.S*. The size is `KSTSIZE = 8*PAGESIZE = 32KB`. The initial value of `esp` is pointed at `bootstacktop`.

```
$ i386-jos-elf-objdump -D obj/kern/kernel | grep bootstack
Disassembly of section .data:
f0110000 <bootstack>:
f0118000 <bootstacktop>:
```

#### Exercise 10

1. Find the address of the `test_backtrace()` function in *obj/kern/kernel.asm*, set a breakpoint there, and examine what happens each time it gets called after the kernel starts. How many 32-bit words does each recursive nesting level of `test_backtrace()` push on the stack, and what are those words?

`call f0100040 <test_backtrace>`: push the `eip` next instruction to the stack, 4 bytes.

`push %ebp`: push previous function's `ebp` base pointer to the stack, 4 bytes.

`push %ebx`: push value on the `ebx` register to the stack, 4 bytes.

`sub $0x14,%esp`: create 0x14 bytes space in the stack, 5 * 4 bytes.

Therefore, each nested `test_backtrace()` has a stack frame of size 32 bytes.

```
/* obj/kern/kernel.asm */
f0100040 <test_backtrace>:
#include <kern/console.h>
// Test the stack backtrace function (lab 1 only)
void test_backtrace(int x) {
f0100040:	55                   	push   %ebp
f0100041:	89 e5                	mov    %esp,%ebp
f0100043:	53                   	push   %ebx
f0100044:	83 ec 14             	sub    $0x14,%esp
f0100047:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("entering test_backtrace %d\n", x);
... ...
}

f010009d <i386_init>:
void i386_init(void) {
... ...
f010010d:	e8 2e ff ff ff       	call   f0100040 <test_backtrace>
	// Drop into the kernel monitor.
	while (1)
		monitor(NULL);
f0100112:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
... ...
}
```

#### Exercise 11

1. Implement the backtrace function `mon_backtrace()` in the [kern/monitor.c](./kern/monitor.c).

Set breakpoints at `f0100106` before calling the `test_backtrace()` for the first time and at the `f0100040 <test_backtrace>`.

```
/* obj/kern/kernel.asm */
void i386_init(void) {
 ... ...
	test_backtrace(5);
f0100106:	c7 04 24 05 00 00 00 	movl   $0x5,(%esp)
f010010d:	e8 2e ff ff ff       	call   f0100040 <test_backtrace>
	while (1)
		monitor(NULL);
f0100112:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
... ...
}

f0100040 <test_backtrace>:
#include <kern/console.h>
void test_backtrace(int x) {
... ...
f0100040:	55                   	push   %ebp
f0100041:	89 e5                	mov    %esp,%ebp
f0100043:	53                   	push   %ebx
f0100044:	83 ec 14             	sub    $0x14,%esp
f0100047:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("entering test_backtrace %d\n", x);
f010004a:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010004e:	c7 04 24 c0 17 10 f0 	movl   $0xf01017c0,(%esp)
f0100055:	e8 c0 08 00 00       	call   f010091a <cprintf>
	if (x > 0)
f010005a:	85 db                	test   %ebx,%ebx
f010005c:	7e 0d                	jle    f010006b <test_backtrace+0x2b>
		test_backtrace(x-1);
f010005e:	8d 43 ff             	lea    -0x1(%ebx),%eax
f0100061:	89 04 24             	mov    %eax,(%esp)
f0100064:	e8 d7 ff ff ff       	call   f0100040 <test_backtrace>
f0100069:	eb 1c                	jmp    f0100087 <test_backtrace+0x47>
	else
		mon_backtrace(0, 0, 0);
... ...
```

Run "continue" in the GDB for several times and stops at the third recursive call. Dump the stack content as below.

`<0xf0117fdc+4>`: value 0x5 is the initial argument pushed to stack by `f0100106: movl $0x5,(%esp)` before calling `test_backtrace(5)`.

`<0xf0117fdc+0>`: `eip` as the return address.

`<0xf0117fdc-4>`: saved last `ebp` by `f0100040: push %ebp`.

`<0xf0117fdc-8>`: saved `ebx` value by `f0100043:	push %ebx`.

`<0xf0117fdc-12> to <0xf0117fdc-20>`: unknown data.

`<0xf0117fdc-24>`: value 0x5 is the last `test_backtrace(5)` argument.

`<0xf0117fcc+4>`: value 0x4 is the current argument before calling the first recursive `test_backtrace(5-1)`.

Repeating from here...

```
(gdb) x/32wx $esp
0xf0117f7c:	0xf0100069	0x00000002	0x00000003	0xf0117fb8
0xf0117f8c:	0x00000000	0xf01008d4	0x00000004	0xf0117fb8
0xf0117f9c:	0xf0100069	0x00000003	0x00000004	0x00000000
0xf0117fac:	0x00000000	0x00000000	0x00000005	0xf0117fd8
0xf0117fbc:	0xf0100069	0x00000004	0x00000005	0x00000000
0xf0117fcc:	0x00010074	0x00010074	0x00010074	0xf0117ff8
0xf0117fdc:	0xf0100112	0x00000005
```

Thus, it is possible to write the `mon_backtrace()` in the [kern/monitor.c](./kern/monitor.c)