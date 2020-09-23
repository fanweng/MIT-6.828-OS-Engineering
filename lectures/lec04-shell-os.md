# Lecture 4: Shell & OS organization

## I. Lecture Topic

Kernel system call API: both details and design; isolation, multiplexing, and sharing

## II. Overview Diagram

* user / kernel
* process = address space + thread(s)
* process is a running program
* app -> printf() -> write() -> SYSTEM CALL -> sys_write() -> ...
* user-level libraries are app's private business
* kernel internal functions are not callable by user

## III. UNIX System Call Observations

### `fork`/`exec` split

It looks that the `fork`/`exec` split is wasteful - `fork()` copies memory, `exec()` discards. Why not `pid = forkexec(path, argv, fd0, fd1)`?

Actually the `fork`/`exec` split is useful:

* the split allows more freedom on the operations: `fork()`; I/O redirection; `exec()` or `fork()`; complex nested command; exit. As in `(cmd1 ; cmd2 ) | cmd3`.
    - `fork()` alone: parallel processing
    - `exec()` alone: /bin/login ... exec("/bin/sh")

* fork is cheap for small programs - on some machine:
    - fork+exec takes 400 microseconds (2500 / second)
    - fork alone takes 80 microseconds (12000 / second)
    - some tricks are involved -- you'll implement them in jos!

### File descriptor design

* FDs are a level of indirection
    - a process's real I/O environment is hidden in the kernel
    - preserved over fork and exec
    - separates I/O setup from use
    - imagine writefile(filename, offset, buf size)
  
* FDs help make programs more general purpose: don't need special cases for files vs console vs pipe

### Philosophy: small set of conceptually simple calls that combine well

* E.g. fork(), open(), dup(), exec()

* command-line design has a similar approach: `ls | wc -l`

### Why system call designed like this?

The core UNIX system calls are ancient; have they held up well? Yes, very successful and evolved well over many years history: design caters to command-line and s/w development system call interface is easy for programmers to use command-line users like named files, pipelines, &c important for development, debugging, server maintenance but the UNIX ideas are not perfect: programmer convenience is often not very valuable for system-call API programmers use libraries e.g. Python that hide syscall details apps may have little to do with files &c, e.g. on smartphone some UNIX abstractions aren't very efficient fork() for multi-GB process is very slow FDs hide specifics that may be important:

* e.g. block size for on-disk files
* e.g. timing and size of network messages

## IV. OS organization

### Main goal: isolation

#### Processors provide user/kernel mode

* kernel mode: can execute "privileged" instructions
    - e.g., setting kernel/user bit
* user mode: cannot execute privileged instructions

#### Operating system runs in kernel mode

* kernel is "trusted"
    - can set user/kernel bit
    - direct hardware access
	  
#### Applications run in user mode

* kernel sets up per-process isolated address space
* system calls switch between user and kernel mode:
    - the application executes a special instruction to enter kernel
    - hardware switches to kernel mode
    - but only at an entry point specified by the kernel

#### What to put in the kernel?

* xv6 follows a traditional design: all of the OS runs in kernel mode
    - one big program with file system, drivers, &c
    - this design is called a monolithic kernel
    - kernel interface == system call interface
    - good: easy for subsystems to cooperate
      one cache shared by file system and virtual memory
    - bad: interactions are complex
      leads to bugs
      no isolation within kernel

* microkernel design
    - many OS services run as ordinary user programs
        + file system in a file server
    - kernel implements minimal mechanism to run services in user space
        + processes with memory
        + inter-process communication (IPC)
    - kernel interface != system call interface		
    - good: more isolation
    - bad: may be hard to get good performance

* exokernel: no abstractions
    - apps can use hardware semi-directly, but O/S isolates
        + e.g. app can read/write own page table, but O/S audits
        + e.g. app can read/write disk blocks, but O/S tracks block owners
    - good: more flexibility for demanding applications
    - jos will be a mix of microkernel and exokernel

* Can one have process isolation WITHOUT h/w-supported kernel/user mode?
    - yes! see Singularity O/S, later in semester
    - but h/w user/kernel mode is the most popular plan