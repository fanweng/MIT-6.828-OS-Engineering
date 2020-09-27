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