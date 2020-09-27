# Lecture 5: Isolation Mechanisms

Multiple processes drive the key requirements:
* multiplexing
* **isolation** (most constraining)
* interaction/sharing

## I. What is isolation?

* the **process** is the usual unit of isolation

* enforced separation to **contain effects of failures**
    - prevent process X from wrecking or spying on process Y r/w memory, use 100% of CPU, change FDs, etc.
    - prevent a process from interfering with the operating system in the face of malice as well as bugs
    - a bad process may try to trick the h/w or kernel

## II. Hardware mechanisms for process isolation:

Kernel uses hardware mechanisms as part of the process isolation:
* user/kernel mode flag
* address spaces
* timeslicing
* system call interface

### Hardware user/kernel mode flag

* controls whether instructions can access privileged h/w

* called `CPL` on the x86, bottom two bits of %cs register
```
CPL=0 -- kernel mode -- privileged
CPL=3 -- user mode -- no privilege
```

* x86 CPL protects many processor registers relevant to isolation
    - I/O port accesses
    - control register accesses (eflags, %cs4, ...), including %cs itself
    - affects memory access permissions, but indirectly the kernel must set all this up correctly

#### How to do a system call -- switching CPL

Q: would this be an OK design for user programs to make a system call?
```
set CPL=0
jmp sys_open
```
A: Bad. The user-specified instructions with CPL=0

Q: how about a combined instruction that sets CPL=0, but *requires* an immediate jump to someplace in the kernel?
A: Bad. The user might jump somewhere awkward in the kernel

Q: so how the x86 do a system call?
A: There are only a few permissible kernel entry points ("vectors") - `INT` instruction sets CPL=0 and jumps to an entry point. But user code can't otherwise modify `CPL` or jump anywhere else in kernel. System call return sets `CPL=3` before returning to user code. Also a combined instruction (can't separately set `CPL` and `jmp`)

The result is a well-defined notion of user vs kernel:
* `CPL=3`: executing user code
* `CPL=0`: executing from entry point in kernel code

The following are **NOT** permitted:
* ~~`CPL=0` and executing user code~~
* ~~`CPL=0` and executing anywhere in kernel~~

### Isolate the process memory

The idea: **address space**

Give each process some memory it can access for its code, variables, heap, stack, preventing it from accessing other memory (kernel or other processes).

#### How to create isolated address spaces?

* xv6 uses x86 *paging hardware* in the **memory management unit (MMU)**

* MMU translates (or "maps") every address issued by program
```
CPU -> MMU -> RAM
        |
     page_table
VA -> PA
```

* MMU translates all memory references: user and kernel, instructions
    - data instructions use only VAs, never PAs

* kernel sets up a different page table for each process
    - each process's page table allows access only to that process's RAM
  
### Let's look at how xv6 system calls are implemented

xv6 process/stack diagram:
  user process ; kernel thread
  user stack ; kernel stack
  two mechanisms:
    switch between user/kernel
    switch between kernel threads
  trap frame
  kernel function calls...
  struct context

* simplified xv6 user/kernel virtual address-space setup
```
FFFFFFFF:
          ...
80000000: kernel
          user stack
          user data
00000000: user instructions
```

* kernel configures MMU to give user code access only to lower half separate address space for each process
    - but kernel (high) mappings are the same for every process

* system call starting point: executing in user space, sh writing its prompt, sh.asm, `write()` library function:
```
(gdb) break *0xd42
(gdb) x/3i
// 0x10 in eax is the system call number for write
(gdb) info reg
// cs=0x1b, B=1011 -- CPL=3 => user mode
// esp and eip are low addresses -- user virtual addresses
(gdb) x/4x $esp
// ebf is return address -- in printf
// 2 is fd
// 0x3f7a is buffer on the stack
// 1 is count
// i.e. write(2, 0x3f7a, 1)
(gdb) x/c 0x3f7a
```

* `INT` instruction, kernel entry:
```
(gdb) stepi
(gdb) info reg
// cs=0x8 -- CPL=3 => kernel mode
// note INT changed eip and esp to high kernel addresses
// where is eip?
//   at a kernel-supplied vector -- only place user can go
//   so user program can't jump to random places in kernel with CPL=0
(gdb) x/6wx $esp
// INT saved a few user registers: err, eip, cs, eflags, esp, ss
// why did INT save just these registers?
//   they are the ones that INT overwrites
// what INT did:
//   switched to current process's kernel stack
//   saved some user registers on kernel stack
//   set CPL=0
//   start executing at kernel-supplied "vector"
// where did esp come from?
//   kernel told h/w what kernel stack to use when creating process
```

#### Q: Why does INT bother saving the user state? How much state should be saved?

* `INT` saves the rest of the user registers on the kernel stack
    - trapasm.S alltraps
    - pushal pushes 8 registers: eax .. edi
    - 19 words at top of kernel stack:
```
x/19x $esp
    ss
    esp
    eflags
    cs
    eip
    err    -- INT saved from here up
    trapno
    ds
    es
    fs
    gs
    eax..edi
```
Those valuses will eventually be restored, when system call returns. Meanwhile the kernel C code sometimes needs to read/write saved values

#### Q: Why are user registers saved on the kernel stack? Why not save them on the user stack?

* entering kernel C code
    - the `pushl %esp` creates an argument for trap(struct trapframe *tf)
    - now we're in trap() in trap.c
    - print tf
    - print *tf

* kernel system call handling
    - device interrupts and faults also enter trap()
    - trapno == T_SYSCALL
    - myproc()
    - struct proc in proc.h
    - myproc()->tf -- so syscall() can get at call # and arguments
    - syscall() in syscall.c
        + looks at tf->eax to find out which system call
    - SYS_write in syscalls[] maps to sys_write
    - sys_write() in sysfile.c
    - arg*() read write(fd,buf,n) arguments from the user stack
    - argint() in syscall.c
        + proc->tf->esp + xxx

* restoring user registers
    - syscall() sets tf->eax to return value
    - back to trap()
    - finish -- returns to trapasm.S
    - info reg -- still in kernel, registers overwritten by kernel code
    - stepi to iret
    - info reg
        + most registers hold restored user values
        + eax has write() return value of 1
        + esp, eip, cs still have kernel values
    - x/5x $esp
        + saved user state: eip, cs, eflags, esp, ss
    - IRET pops those user registers from the stack
        + and thereby re-enters user space with CPL=3