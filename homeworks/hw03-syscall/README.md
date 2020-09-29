# Homework 3 - System Calls

## 0. Software Setup

Reuse the xv6-public source code from [Homework 1](../hw01-boot-xv6/xv6-public).

```sh
$ cd xv6-public
$ make
```

## 1. System Call Tracing

Modify the `syscall()` in the *syscall.c*, printing out the name of system call and the return value.

## 2. New System Call - Date

Create a new system call that gets the current UTC time and return it to the user program. To add a new system call, we can take the `uptime` syscall as an example, reviewing all source code related to `uptime`.

```sh
$ grep -n uptime *.[chS]
syscall.c:105:extern int sys_uptime(void);
syscall.c:121:[SYS_uptime]  sys_uptime,
syscall.h:15:#define SYS_uptime 14
sysproc.c:83:sys_uptime(void)
user.h:25:int uptime(void);
usys.S:31:SYSCALL(uptime)
```

In the *syscall.c*, the `sys_date` entry is added to the `syscalls[]` function array and declared as an `extern` function.

In the *syscall.h*, number 22 is reserved for `SYS_date`.

The implementation of ystem calls are defined in the *sysproc.c* and *sysfile.c*. The `sys_date` is not file-related so its definition should be put in the *sysproc.c*. Use `argptr()` from *syscall.c* to fetch the argument as a pointer, and call `cmostime()` from *lapic.c* to get the current time.

At last, add `date` to the *user.h* and *usys.S* as an interface so that user can call it.