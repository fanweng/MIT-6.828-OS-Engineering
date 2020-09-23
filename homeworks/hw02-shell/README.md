# Homework 2 - Shell

## 0. Software setup

The course provides a shell script [t.sh](./t.sh) with an incomplete xv6 shell source code [sh.c](./sh.c) at the beginning. Build the shell executable and run the script, the execution will output error messages because some features haven't been implemented in the shell source code.

```sh
$ gcc sh.c
$ ./a.out < t.sh
redir not implemented
exec not implemented
pipe not implemented
exec not implemented
exec not implemented
pipe not implemented
exec not implemented
```

Read Chapter 0 of the [xv6 book](../../resources/xv6-book-rev11.pdf).

## 1. Feature Implementation

### `exec`

Try a simple `ls` command in the built shell environment, error message will show up because `case ' '` in the `runcmd()` hasn't been implemented.

```sh
$ ./a.out 
6.828$ ls
exec not implemented
```

To accomplish that, `execv(const char *pathname, char *const argv[]))` is used and if it returns any error, we exit. Since this simple shell doesn't have a search `PATH` implemented, running `ls` will still encounter an error because shell cannot find the `ls` binary in the current working directory. Use an aboslute path `/bin/ls` to pass that.

```sh
6.828$ ls
execv failed(2): No such file or directory
6.828$ /bin/ls
README.md       a.out           sh.c            t.sh
```

### I/O redirection

The parser already recognizes `>` and `<`, and builds a `redircmd`. I only need to open the file in the `runcmd()` accordingly using `open(const char *pathname, int flags, mode_t mode)`.

```sh
6.828$ /bin/echo "6.828 is cool" > x.txt
6.828$ /bin/cat < x.txt
"6.828 is cool"
```

### Pipes

The parser already recognizes `|`, and builds a `pipecmd`. I need to create a pipe using `pipe(int pipefd[2])`, fork child processes for left and right commands, redirect the STDOUT/STDIN accordingly by `dup2(int oldfd, int newfd)`, close the unused pipe ends and fds, and run commands. At the end, parent process needs to wait for the child processes using `wait(int *wstatus)`.

```sh
6.828$ /bin/ls | /usr/bin/sort | /usr/bin/uniq | /usr/bin/wc
       4       4      26
```

## 2. Homework 2 Solution

* Let's review Homework 2 (sh.c)
  * exec
    why two execv() arguments?
    what happens to the arguments?
    what happens when exec'd process finishes?
    can execv() return?
    how is the shell able to continue after the command finishes?
  * redirect
    how does exec'd process learn about redirects? [kernel fd tables]
    does the redirect (or error exit) affect the main shell?
  * pipe
    ls | wc -l
    what if ls produces output faster than wc consumes it?
    what if ls is slower than wc?
    how does each command decide when to exit?
    what if reader didn't close the write end? [try it]
    what if writer didn't close the read end?
    how does the kernel know when to free the pipe buffer?

  * how does the shell know a pipeline is finished?
    e.g. ls | sort | tail -1

  * what's the tree of processes?
    sh parses as: ls | (sort | tail -1)
          sh
          sh1
      ls      sh2
          sort   tail

  * does the shell need to fork so many times?
    - what if sh didn't fork for pcmd->left? [try it]
      i.e. called runcmd() without forking?
    - what if sh didn't fork for pcmd->right? [try it]
      would user-visible behavior change?
      sleep 10 | echo hi

  * why wait() for pipe processes only after both are started?
    what if sh wait()ed for pcmd->left before 2nd fork? [try it]
      ls | wc -l
      cat < big | wc -l

  * the point: the system calls can be combined in many ways
    to obtain different behaviors.

Let's look at the challenge problems

 * How to implement sequencing with ";"?
   gcc sh.c ; ./a.out
   echo a ; echo b
   why wait() before scmd->right? [try it]

 * How to implement "&"?
   $ sleep 5 & 
   $ wait
   the implementation of & and wait is in main -- why?
   What if a background process exits while sh waits for a foreground process?

 * How to implement nesting?
   $ (echo a; echo b) | wc -l
   my ( ... ) implementation is only in sh's parser, not runcmd()
   it's neat that sh pipe code doesn't have to know it's applying to a sequence

 * How do these differ? 
   echo a > x ; echo b > x
   ( echo a ; echo b ) > x
   what's the mechanism th