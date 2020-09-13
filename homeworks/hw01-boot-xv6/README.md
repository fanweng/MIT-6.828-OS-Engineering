# Homework 1 - Boot xv6

## 0. Software setup

Assume all tools used in Lab 1 are installed, thus we can fetch the xv6 source and build the xv6:

```sh
$ git clone git://github.com/mit-pdos/xv6-public.git
Cloning into 'xv6-public'...
$ cd xv6-public
$ make
```

## 1. Find and break at an address

Let's find the entry point of the kernel, the address of `_start`, using `nm` command which is used to examine and display the content of a binary file. In this case, `_start` is at `0x0010000c`.

```sh
$ nm kernel | grep _start
8010948c D _binary_entryother_start
80109460 D _binary_initcode_start
0010000c T _start
```

Run the kernel inside QEMU GDB.

```sh
$ make qemu-nox-gdb
*** Now run 'gdb'.
qemu-system-i386 -nographic -drive file=fs.img,index=1,media=disk,format=raw -drive file=xv6.img,index=0,media=disk,format=raw -smp 2 -m 512  -S -gdb tcp::25501
```

Open another terminal for GDB and set the breakpoint at `0x0010000c`.

```sh
$ i386-jos-elf-gdb
+ target remote localhost:25501
The target architecture is assumed to be i8086
[f000:fff0]    0xffff0:	ljmp   $0xf000,$0xe05b
0x0000fff0 in ?? ()
+ symbol-file kernel
(gdb) b *0x0010000c
Breakpoint 1 at 0x10000c
(gdb) c
Continuing.
The target architecture is assumed to be i386
=> 0x10000c:	mov    %cr4,%eax

Breakpoint 1, 0x0010000c in ?? ()
```

## 2. Exercise of stack contents?

**Supporting files:** *bootasm.S*, *bootmain.c* and *bootblock.asm*.

#### Where in *bootasm.S* is the stack pointer initialized?

```sh
# Set up the stack pointer and call into C.
movl    $start, %esp    <= init here
call    bootmain
```

#### Step through the call to `bootmain()`, what is on the stack?

First, calling `bootmain()` (at `0x7d2a`) pushes the `%ebp` to the stack, a return address `0x7c4d`.

```sh
(gdb) si
=> 0x7c48:	call   0x7d2a
0x00007c48 in ?? ()
(gdb) x/4x $esp
0x7c00:	0x8ec031fa	0x8ec08ed8	0xa864e4d0	0xb0fa7502
(gdb) si
=> 0x7d2a:	push   %ebp
0x00007d2a in ?? ()
(gdb) x/4x $esp
0x7bfc:	0x00007c4d	0x8ec031fa	0x8ec08ed8	0xa864e4d0
```

Then prologue in the `bootmain()` makes a stack frame.

```sh
void bootmain(void) {
    7d2a:	55                   	push   %ebp
    7d2b:	89 e5                	mov    %esp,%ebp
    7d2d:	57                   	push   %edi
    7d2e:	56                   	push   %esi
    7d2f:	53                   	push   %ebx
    7d30:	83 ec 2c             	sub    $0x2c,%esp
```

At last, calling `entry()` at the end of `bootmain()` pushes a return address `0x7db8`.

```
... ...
  entry = (void(*)(void))(elf->entry);
  entry();
    7db2:	ff 15 18 00 01 00    	call   *0x10018
}
    7db8:	83 c4 2c             	add    $0x2c,%esp
```

#### Step to the entry point of the kernel, What is on the stack?

While stopped at the `_start`, examine the registers and stack contents.

```sh
(gdb) info reg
eax            0x0	0
ecx            0x0	0
edx            0x1f0	496
ebx            0x10074	65652
esp            0x7bbc	0x7bbc
ebp            0x7bf8	0x7bf8
esi            0x107000	1077248
edi            0x1144a8	1131688
eip            0x10000c	0x10000c
eflags         0x46	[ PF ZF ]
cs             0x8	8
ss             0x10	16
ds             0x10	16
es             0x10	16
fs             0x0	0
gs             0x0	0
```

```sh
(gdb) x/24x $esp
0x7bbc:	0x00007db8	0x00107000	0x00002516	0x00008000
0x7bcc:	0x00000000	0x00000000	0x00000000	0x00000000
0x7bdc:	0x00010074	0x00000000	0x00000000	0x00000000
0x7bec:	0x00000000	0x00000000	0x00000000	0x00000000
0x7bfc:	0x00007c4d	0x8ec031fa	0x8ec08ed8	0xa864e4d0
0x7c0c:	0xb0fa7502	0xe464e6d1	0x7502a864	0xe6dfb0fa
```

The stack contents are:

```
0x7c00:  0x8ec031fa  => not the stack!
0x7bfc:  0x00007cd4  => bootmain() return address
0x7bf8:  0x00000000  => old $ebp
0x7bf4:  0x00000000  => old $edi
0x7bf0:  0x00000000  => old $esi
0x7bec:  0x00000000  => old $ebx
0x7be8:  0x00000000  => start of moving $esp by 0x2c bytes
0x7be4:  0x00000000
0x7be0:  0x00000000
0x7bdc:  0x00010074
0x7bd8:  0x00000000
0x7bd4:  0x00000000
0x7bd0:  0x00000000
0x7bcc:  0x00000000
0x7bc8:  0x00008000
0x7bc4:  0x00002516
0x7bc0:  0x00107000  => end of moving $esp by 0x2c bytes
0x7bbc:  0x00007db8  => entry() return address
```