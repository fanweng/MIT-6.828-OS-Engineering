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