# From Scratch OS — 里程碑计划

> 每个里程碑都有一个明确的**通关测试**：你在终端看到特定输出就算过关。
> 没有骨架代码。没有完形填空。只有你、空文件、xv6 源码、和 AI 翻译官。

---

## 准备工作 (30 分钟)

```bash
# 运行 setup.sh，确认这三行都有输出：
qemu-system-riscv64 --version   # QEMU emulator version 8.x+
rustc --version                  # rustc 1.7x+
cargo objcopy --version          # cargo-objcopy 0.3x+
```

在你电脑上另开一个窗口，clone xv6 源码当参考：
```bash
git clone https://github.com/mit-pdos/xv6-riscv.git ~/xv6-ref
```

**规则：可以看 xv6 的 C 源码理解概念，但 Rust 代码必须自己写。遇到不懂的问 AI。**

---

## M0 — 虚空中的第一个字节 (Day 1)

**目标：** 让 QEMU 启动你的代码，在串口输出一个字符。

**你需要搞明白的事：**
- QEMU virt machine 启动时 CPU 从哪个地址开始执行？(0x80000000)
- RISC-V 裸机启动时需要设置什么？(栈指针 sp)
- UART 16550 的寄存器地址在 QEMU virt 上是什么？(0x10000000)
- 怎么往 UART 写一个字节？(往那个地址写一个 byte)

**要创建的文件：**
```
my-os/
├── Cargo.toml
├── rust-toolchain.toml      # 指定 nightly + riscv64 target
├── .cargo/config.toml       # 链接器脚本路径、target 配置
├── src/
│   ├── main.rs              # #![no_std] #![no_main] + panic handler
│   ├── entry.asm            # _start: 设栈, 跳到 rust_main
│   └── linker.ld            # 告诉链接器把代码放在 0x80000000
└── Makefile                 # build + run 命令
```

**参考 xv6 文件：** `kernel/entry.S`, `kernel/uart.c`

**Makefile 中的运行命令：**
```makefile
run:
	cargo build --release
	qemu-system-riscv64 \
		-machine virt \
		-nographic \
		-bios none \
		-kernel target/riscv64gc-unknown-none-elf/release/my-os
```

**通关测试：**
```
$ make run
H
```
终端输出一个 `H`。就一个字母。这代表你的代码跑在了 RISC-V CPU 上。

**如果卡住：** 问 AI "我有一个空的 Rust no_std 项目，target 是 riscv64gc-unknown-none-elf，我需要写 linker script 把 _start 放在 0x80000000，然后设栈，然后往 UART 0x10000000 写一个字节。我不知道怎么开始。"

---

## M1 — 让机器说话 (Day 2-3)

**目标：** 实现 `print!` 宏，能打印字符串和数字。

**你需要搞明白的事：**
- Rust 的 `core::fmt::Write` trait 怎么用？
- 怎么实现一个全局的 Writer 让 print! 宏能用？
- 为什么需要 `spin lock` 或 `unsafe static`？

**通关测试：**
```
$ make run

============================
  my-os v0.1
  RISC-V 64, QEMU virt
============================

Hello from Rust on bare metal!
The answer is: 42
Memory starts at: 0x80000000
```

**算法知识点：** 无。这一步是纯系统编程。
**参考 xv6 文件：** `kernel/printf.c`, `kernel/uart.c`, `kernel/console.c`

---

## M2 — 认识自己的身体 (Day 4-6)

**目标：** 物理内存管理。把可用 RAM 切成 4KB 页，用空闲链表管理。

**你需要搞明白的事：**
- QEMU virt 的内存布局是什么？(linker script 的 _end 之后到 0x88000000)
- 什么是空闲链表 (free list)？每个空闲页的前 8 字节指向下一个空闲页。
- `kalloc()` = 从链表头拿一页。`kfree()` = 放回链表头。两个函数，各 5 行。

**通关测试：**
```
$ make run
Physical memory: 0x80221000 - 0x88000000
Free pages: 31xxx
Allocated page at: 0x80221000
Allocated page at: 0x80222000
Freed page: 0x80222000
Freed page: 0x80221000
Free pages: 31xxx  ← 和开始一样
```

分配两页，释放两页，计数回到原值。你的内存管理器没有泄漏。

**算法知识点：** 链表（最简单的数据结构，但在这里你会深刻理解"指针就是地址"）。
**参考 xv6 文件：** `kernel/kalloc.c`（只有 ~80 行！）

---

## M3 — 创造虚拟世界 (Day 7-12)

**目标：** 实现 RISC-V Sv39 页表。把虚拟地址映射到物理地址。

**你需要搞明白的事：**
- RISC-V Sv39 的三级页表结构（每级 512 个条目，每条目 8 字节）
- PTE (Page Table Entry) 的 flag 位：V(valid), R(read), W(write), X(execute), U(user)
- `satp` 寄存器怎么设置来启用分页
- 什么是 identity mapping（虚拟地址 = 物理地址，内核启动时用）

**通关测试：**
```
$ make run
Page table created at: 0x80223000
Mapped 0x80000000 -> 0x80000000 (kernel text, RX)
Mapped 0x80200000 -> 0x80200000 (kernel data, RW)
Mapped 0x10000000 -> 0x10000000 (UART, RW)
Enabling paging...
Paging enabled! Still alive!
Virtual memory works: print after paging ✓
```

"Still alive" 这两个字意义重大——说明你的页表映射正确，CPU 在分页模式下还能找到你的代码和 UART。如果映射错了，CPU 会立刻 trap 然后挂死。

**算法知识点：** 多级索引（页表就是一棵 512 叉树）。理解这个之后，B-tree 对你来说就是同一个思想的变体。
**参考 xv6 文件：** `kernel/vm.c`（这是 xv6 最长的文件，~300 行，慢慢读）

---

## M4 — 中断与异常 (Day 13-16)

**目标：** 实现 trap handler。能响应时钟中断和非法指令异常。

**你需要搞明白的事：**
- RISC-V 的 `stvec` 寄存器（trap 入口地址）
- `scause` 寄存器（为什么陷入？时钟？系统调用？非法指令？）
- `sepc` 寄存器（陷入时的 PC，用于返回）
- trap 入口必须用汇编保存所有寄存器，然后调用 Rust 函数

**通关测试：**
```
$ make run
Trap handler installed
Timer interrupt #1 at tick 0
Timer interrupt #2 at tick 1
Timer interrupt #3 at tick 2
Triggering illegal instruction...
EXCEPTION: illegal instruction at 0x802xxxxx
  scause: 2
  stval:  0x0
Recovered! System still running.
Timer interrupt #4 at tick 3
```

时钟中断规律地触发（说明中断通路正常），然后故意触发一个异常，trap handler 捕获并恢复。

**算法知识点：** 无（但你会理解函数调用的本质——保存寄存器 + 跳转 + 恢复寄存器）。
**参考 xv6 文件：** `kernel/trap.c`, `kernel/trampoline.S`, `kernel/kernelvec.S`

---

## M5 — 一生二 (Day 17-24) ⭐

**目标：** 实现进程和 fork。两个进程交替运行。

**你需要搞明白的事：**
- `struct Process`：pid, state, kernel_stack, page_table, context (saved registers), trapframe
- 上下文切换：保存 14 个 callee-saved 寄存器，加载另一组（就是 xv6 的 swtch.S）
- 简单轮转调度器：遍历进程表，找到 RUNNABLE 的，swtch 过去
- fork：分配新进程，复制页表(uvmcopy)，复制 trapframe，设 a0=0

**通关测试：**
```
$ make run
Process 1 created
Process 2 forked from process 1
[P1] tick 0
[P2] tick 0
[P1] tick 1
[P2] tick 1
[P1] tick 2
[P2] tick 2
fork() returned 2 in parent
fork() returned 0 in child
```

两个进程交替打印。这代表你的调度器和上下文切换都工作了。

**算法知识点：** 轮转调度（Round Robin）——最简单的调度算法。之后可以升级为优先队列调度。
**参考 xv6 文件：** `kernel/proc.c`（重点看 allocproc, kfork, scheduler）, `kernel/swtch.S`

---

## M6 — 管道连接世界 (Day 25-30) ⭐

**目标：** 实现 pipe。两个进程通过管道通信。

**你需要搞明白的事：**
- 环形缓冲区 (ring buffer)：一个 char 数组 + read 指针 + write 指针
- sleep / wakeup 机制：进程等待条件满足时让出 CPU
- 文件描述符表：每个进程有一个 fd 数组，指向不同类型的"文件"（pipe 也是 file）

**通关测试：**
```
$ make run
Pipe created: read_fd=3, write_fd=4
[Writer] sending: Hello from pipe!
[Reader] received: Hello from pipe!
[Writer] sending: Unix philosophy works!
[Reader] received: Unix philosophy works!
[Writer] closed write end
[Reader] got EOF
```

两个进程，一个写，一个读。writer 关闭后 reader 收到 EOF。这就是 `echo "hello" | cat` 的底层原理。

**算法知识点：** 环形缓冲区（ring buffer）——一个数组用取模运算变成循环队列。这个数据结构在网络栈（TCP 滑动窗口）、音频处理、Linux 内核（kfifo）里到处都是。
**参考 xv6 文件：** `kernel/pipe.c`（完整实现不到 100 行）

---

## M7 — 文件系统 (Day 31-42)

**目标：** 实现一个简单的磁盘文件系统。能 ls、cat、write。

**你需要搞明白的事：**
- virtio block device 驱动（QEMU 的虚拟磁盘接口）
- block cache（buffer pool）：在内存中缓存磁盘块，LRU 淘汰
- inode：文件的元数据（大小、类型、数据块地址）
- 目录：特殊的文件，内容是 (name, inode_number) 对
- 路径解析：`/home/readme.txt` → 找 `/` 的 inode → 在其中找 `home` → 在其中找 `readme.txt`

**通关测试：**
```
$ make run
Filesystem mounted
# ls
.        1
..       1
readme   2
hello    3
# cat readme
This file is on a virtual disk!
# write test Hello World
Written 11 bytes to 'test'
# ls
.        1
..       1
readme   2
hello    3
test     4
# cat test
Hello World
```

你的文件系统能创建文件、读文件、列目录。数据存在虚拟磁盘上，重启后还在。

**算法知识点：**
- B-tree 的简化版（inode 的间接块指针本质上是一棵树）
- LRU 缓存淘汰（buffer pool 需要决定丢弃哪个页）
- 哈希表（block cache 用 hash 快速查找）

**参考 xv6 文件：** `kernel/fs.c`, `kernel/bio.c`, `kernel/virtio_disk.c`, `kernel/log.c`

---

## M8 — Shell: 大一统 (Day 43-50)

**目标：** 实现 exec() 和一个最小的用户态 shell。

**你需要搞明白的事：**
- ELF 文件格式：用户程序编译成 ELF，exec 解析它并加载到新地址空间
- 系统调用接口：用户态通过 `ecall` 指令陷入内核
- shell 循环：读一行 → fork → exec (子进程) / wait (父进程)
- 管道语法：`ls | grep foo` = fork 两个进程 + pipe 连接 + exec 各自的程序

**通关测试：**
```
$ make run
my-os v0.8 — built from scratch
# echo hello world
hello world
# ls
readme  hello  test
# cat readme
This file is on a virtual disk!
# echo pipe test | cat
pipe test
# exit
Goodbye.
```

一个真正的 shell，能运行命令、支持管道。你从零到一造出了一个操作系统。

---

## 时间线总览

| 里程碑 | 天数 | 核心概念 | 数据结构/算法 |
|--------|------|---------|--------------|
| M0 输出字符 | 1 | 裸机启动, MMIO | 无 |
| M1 print! | 2-3 | Rust trait, 格式化 | 无 |
| M2 内存管理 | 4-6 | 物理页分配 | 链表 |
| M3 页表 | 7-12 | 虚拟内存, Sv39 | 多级索引(树) |
| M4 中断 | 13-16 | trap, 时钟 | 无 |
| M5 fork | 17-24 | 进程, 调度 | 队列, 轮转 |
| M6 pipe | 25-30 | IPC, sleep/wakeup | 环形缓冲区 |
| M7 文件系统 | 31-42 | 磁盘, inode | B-tree简化, LRU, hash |
| M8 shell | 43-50 | exec, syscall | ELF 解析 |

**50 天，8 个里程碑，每个都有"看到输出就算过关"的明确反馈。**

---

## 每天的工作流

1. 打开 xv6 对应的 C 文件，读一遍，问 AI "逐行翻译这段 C 代码"
2. 合上 xv6，打开你自己的 Rust 文件，凭理解写
3. 写完 `make run`，看输出
4. 如果不工作，加 print 调试（你有 UART 就够了）
5. 如果完全卡住，问 AI "我在写 xxx，期望 yyy，但看到 zzz，这是我的代码"
6. 通关后，在每个里程碑的 commit message 里写一句话：这一步我学到了什么

---

*Go build. The terminal is waiting for your first `H`.*
