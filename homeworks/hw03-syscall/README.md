# Homework 3 - System Calls

## 0. Software Setup

Reuse the xv6-public source code from [Homework 1](../hw01-boot-xv6/xv6-public).

```sh
$ cd xv6-public
$ make
```

## 1. System Call Tracing

Modify the `syscall()` in the *syscall.c*, printing out the name of system call and the return value.