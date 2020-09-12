# Lab 2 - Memory Management

## 0. Software Setup

Check out the Lab 2 source code and manually copy all changed files from Lab 1 to Lab 2 folder (`kern/console.c`, `kern/init.c`, `kern/kdebug.c`, `kern/monitor.c`, `lib/printfmt.c`).

```sh
$ git clone https://pdos.csail.mit.edu/6.828/2018/jos.git labs/lab02-mem-management
$ cd labs/lab02-mem-management
$ git checkout -b lab2 origin/lab2
$ rm -rf .git/
(Then copy all chagned files to Lab 2 folder)
```

Lab 2 contains the following new source files:
* `inc/memlayout.h`
* `kern/pmap.c`
* `kern/pmap.h`
* `kern/kclock.c`
* `kern/kclock.h`