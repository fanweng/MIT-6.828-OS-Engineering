# Homework 4 - Lazy Page Allocation

From this homework and the later ones, only one copy of xv6 source code *homeworks/xv6-public* will be kept. All changes will be added to that copy. This baseline is copied from *hw03-syscall*.

## Objective

There are programs that ask the kernel for heap memory using `sbrk()` system call, and `sbrk()` allcoates physical memory and maps it into process's virtual address space. But some allocates memory while never uses it, for example, implementing large sparse arrays. Kernel can delay the allocation of each page of memory until the program tries to use that page - signaled by a **page fault**.

## Code Changes

1. Eliminate the allocation from `sbrk()`

In the `sys_sbrk()` from *sysproc.c*, I remove the page allocation `growproc()` and increase the process's size `myproc()->sz` by `n`. Build the xv6 kernel and current it should break:

```sh
init: starting sh
$ echo hello
pid 3 sh: trap 14 err 6 on cpu 0 eip 0x1018 addr 0x4004--kill proc
```

The "pid 3 sh: trap..." message is from the kernel trap handler in *trap.c*; it has caught a page fault (trap 14, or `T_PGFLT`), which the xv6 kernel does not know how to handle. The "addr 0x4004" indicates that the virtual address that caused the page fault is 0x4004.