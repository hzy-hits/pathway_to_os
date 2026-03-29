// my-os: 从零开始
//
// 这个文件几乎是空的。你需要自己写所有东西。
//
// M0 的目标：往 UART (0x10000000) 写一个字节 'H'
//
// 你需要：
// 1. 写 src/linker.ld — 告诉链接器把代码放在 0x80000000
//    提示：看 xv6 的 kernel/kernel.ld
//
// 2. 写启动汇编 — 设置栈指针 sp，然后 call rust_main
//    提示：看 xv6 的 kernel/entry.S
//    在 Rust 中用 core::arch::global_asm! 嵌入汇编
//
// 3. 在 rust_main 中，往地址 0x1000_0000 写一个字节
//    提示：这就是 MMIO (memory-mapped I/O)
//    在 Rust 中用 core::ptr::write_volatile
//
// 当你 make run 看到终端输出 'H' 的时候，M0 通关。
//
// 如果卡住了，打开 xv6-ref/kernel/entry.S 和 kernel/uart.c 看看。
// 或者直接问 AI："我想在 riscv64 裸机上往 0x10000000 写一个字节，
//   Rust no_std 项目，怎么写 linker script 和启动汇编？"

#![no_std]
#![no_main]

// TODO: 你的 panic handler
// TODO: 你的启动汇编 (global_asm!)
// TODO: 你的 rust_main 函数
