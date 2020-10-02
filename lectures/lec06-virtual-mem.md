# Lecture 6: Virtual Memory

* address spaces
* paging hardware
* xv6 VM code

Lecture PDF version is [HERE](../resources/virtual-memory.pdf). 

## I. Virtual memory overview

Suppose the shell has a bug - sometimes it writes to a random memory address. How can we keep it from wrecking the kernel? And from wrecking other processes? We want **isolated address spaces** - each process has its own memory.

* it can read and write its own memory
* it cannot read or write anything else
  
**Challenge**: how to multiplex several memories over one physical memory? While maintaining isolation between memories.

> xv6 and JOS uses x86's paging hardware to implement Address Spaces (AS's)

### Paging

Paging provides a level of indirection for addressing. Kernel tells MMU how to map each virtual address to a physical address. MMU essentially has a table (**Page Table**), indexed by *VA*, yielding *PA*.
```
  CPU -> MMU -> RAM
      VA     PA
```

S/W can only ld/st to the virtual addresses, not physical addresses. MMU can restrict what virtual addresses user code can use.

x86 maps 4-KB "pages" and aligned - start on 4 KB boundaries, thus page table index is top 20 bits of *VA*.

x86 uses a "two-level page table" to save space: page directory (PD) + page table (PT). Both PD and PT are stored in the RAM.

A total of 1024 PD entries (PDEs) that each contains 20-bit PPN, pointing to a page of 1024 PT entries (PTEs) - so 1024*1024 PTEs in total.

PDE can be invalid, which means those PTE pages need not exist. So a page table for a small address space can be small.

#### What is in a page table entry (PTE)?

See [x86 VA translation](../resources/x86-translation-and-registers.pdf).

> page_table_entry = PPN (20-bit) + flags (12-bit)

**Physical Page Number (PPN)**: the same as the top 20 bits of a physical address. MMU replaces top 20 bits of *VA* with PPN later.
**Flags**: 12-bit flag field, e.g. Present, Writeable, User (used by xv6 to forbid user from using kernel memory), etc.

#### Where is the page table stored?

In RAM - MMU loads (and stores) PTEs. OS can read/write PTEs.

#### How does the MMU know where the page table is located in RAM?

`%cr3` holds physical address of PD. PD holds physical address of PTE pages. They can be anywhere in RAM - need not be contiguous.

#### How does x86 paging hardware translate a virtual address?

To find the correct physical address it to find the correct PTE:

* `%cr3` points to physical address of PD
* top 10 bits of virtual address index PD to get the physical address of PT
* next 10 bits of virtual address index PT to get the PTE
* PPN from PTE + lower 12 bits from virtual address = Physical Address

#### How page fault is handled?

CPU saves registers, forces transfer to kernel, i.e. *trap.c* in xv6 source. Kernel can just produce error, kill process or kernel can install a PTE, resume the process, e.g. after loading the page of memory from disk.

#### What are the benefits of memory mapping?

The indirection allows paging h/w to solve many problems:

* avoids fragmentation
* copy-on-write fork
* lazy allocation (home work for next lecture)
* and more...

## II. Case study: xv6 use of the x86 paging hardware

* Big picture of an xv6 address space -- one per process
```
  0x00000000:0x80000000 -- user addresses below KERNBASE
  0x80000000:0x80100000 -- map low 1MB devices (for kernel)
  0x80100000:?          -- kernel instructions/data
  ?         :0x8E000000 -- 224 MB of DRAM mapped here
  0xFE000000:0x00000000 -- more memory-mapped devices
```

* Each process has its own address space and its own page table

* All processes have the same kernel (high memory) mappings. Kernel switches page tables (i.e. sets `%cr3`) when switching processes

### xv6 virtual memory code

Terminology: virtual memory = address space / translation

<!---

start where Robert left off: first process

setup: CPUS=1, turn-off interrupts in lapic.c
b proc.c:297

p *p
Q: are these addresses virtual addresses

break into qemu: info pg (modified 6.828 qemu)

step into switchuvm

x/1024x p->pgdir
what is 0x0dfbc007?  (pde; see handout)
what is 0x0dfbc000?
what is 0x0dfbc000 + 0x8000000
what is there? (pte)
what is at 0x8dfbd000?
x x/i 0x8dfbd000 (first word of initcode.asm)

step passed lcr3

qemu: info pg

-->

* where did this pgdir get setup?
  look at vm.c: setupkvm and inituvm

* mappages() in vm.c
  arguments are PD, va, size, pa, perm
  adds mappings from a range of va's to corresponding pa's
  rounds b/c some uses pass in non-page-aligned addresses
  for each page-aligned address in the range
    call walkpgdir to find address of PTE
      need the PTE's address (not just content) b/c we want to modify
    put the desired pa into the PTE
    mark PTE as valid w/ PTE_P

* diagram of PD &c, as following steps build it

* walkpgdir() in vm.c
  mimics how the paging h/w finds the PTE for an address
  refer to the handout
  PDX extracts top ten bits
  &pgdir[PDX(va)] is the address of the relevant PDE
  now *pde is the PDE
  if PTE_P
    the relevant page-table page already exists
    PTE_ADDR extracts the PPN from the PDE
    p2v() adds 0x80000000, since PTE holds physical address
  if not PTE_P
    alloc a page-table page
    fill in PDE with PPN -- thus v2p
  now the PTE we want is in the page-table page
    at offset PTX(va)
    which is 2nd 10 bits of va


<!--

finish starting the first user process

return to gdb

(draw picture of kstack)
p /x p->tf
p /x *p->tf
p /x p->context
p /x p->context

b *0x0

swtch
x/8x $esp
forkret
x/19x $esp
info reg

step till user space:
x/i 0x0

step through use code
trap into kernel

x/19x $esp

-->

* tracing and date system call

<!-- homework
syscall trace 
  syscall.c (HWSYS)
  return value in eax
  use STAB for printing out names
date
  usys.S
  syscall.c (HWDATE)
  argptr
-->

#### `sbrk()`

A process calls `sbrk(n)` to ask for `n` more bytes of heap memory. `sbrk()` allocates physical memory (RAM), maps it into the process's page table, and returns the starting address of the new memory. Kernel adds new memory at process's end, increasing the process size.

`malloc()` uses `sbrk()`.

* sys_sbrk() in sysproc.c
<!---
   trace sbrk from user space
   just run ls (or any other cmd from shell)
   the new process forked by shell calls malloc for execcmd structure
   malloc.c calls sbrk
-->

* growproc() in proc.c
  proc->sz is the process's current size
  allocuvm() does most of the work
  switchuvm sets %cr3 with new page table
    also flushes some MMU caches so it will see new PTEs

* allocuvm() in vm.c
  why if(newsz >= KERNBASE) ?
  why PGROUNDUP?
  arguments to mappages()...