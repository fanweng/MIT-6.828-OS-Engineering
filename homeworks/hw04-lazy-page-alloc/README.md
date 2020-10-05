# Homework 4 - Lazy Page Allocation

From this homework and the later ones, only one copy of xv6 source code *homeworks/xv6-public* will be kept. All changes will be added to that copy. This baseline is copied from *hw03-syscall*.

## Objective

There are programs that ask the kernel for heap memory using `sbrk()` system call, and `sbrk()` allcoates physical memory and maps it into process's virtual address space. But some allocates memory while never uses it, for example, implementing large sparse arrays. Kernel can delay the allocation of each page of memory until the program tries to use that page - signaled by a **page fault**.