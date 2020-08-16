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