# Lab 1 - Booting a PC

## 0. Software Setup

The lab must use an x86 Athena machine:
```sh
$ uname -a
(i386 GNU/Linux or i686 GNU/Linux or x86_64 GNU/Linux)
```

If having a non-Athena machine, we need to install **QEMU** (an x86 emulator for running the kernel) and possibly **GCC** (a compiler toolchain including assembler, liner, C compiler and debugger for compiling and testing the kernel) following the instructions on the [tool page](https://pdos.csail.mit.edu/6.828/2018/tools.html). My machine is a **MacOS**, and here are the instructions:

1. Install developer tools on MacOS:
`$ xcode-select --install`

2. Install the QEMU dependencies from homebrew. But don't install qemu itself because we need the 6.828 patched version:
`$ brew install $(brew deps qemu)`

3. Build 6.828 patched QEMU:
    - Clone the 6.828 QEMU repo.
    `$ git clone https://github.com/mit-pdos/6.828-qemu.git labs/qemu`
    - Configure the source code. If not specifying the `--prefix`, the QEMU will be installed to `/usr/local` by default.
    `$ ./configure --disable-kvm --disable-werror --disable-sdl --prefix=[INSTALL_DESTINATION] --target-list="i386-softmmu x86_64-softmmu"`
    - Build the QEMU binary.
    `$ make`
    - Install the QEMU binary. The gettext utility doesn't add installed binaries to the PATH, so we need to run:
    `$ PATH=${PATH}:/usr/local/opt/gettext/bin make install`

## 1. PC Bootstrap

Check out the Lab 1 source code:
`$ git clone https://pdos.csail.mit.edu/6.828/2018/jos.git labs/lab01-boot-pc`