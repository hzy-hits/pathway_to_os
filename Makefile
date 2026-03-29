KERNEL = target/riscv64gc-unknown-none-elf/release/my-os

.PHONY: build run clean debug

build:
	cargo build --release

run: build
	qemu-system-riscv64 \
		-machine virt \
		-nographic \
		-bios none \
		-kernel $(KERNEL)

# 带 GDB 调试（另开终端 gdb-multiarch -ex 'target remote :1234'）
debug: build
	qemu-system-riscv64 \
		-machine virt \
		-nographic \
		-bios none \
		-kernel $(KERNEL) \
		-s -S

# 查看生成的汇编（确认你的代码在 0x80000000）
disasm: build
	cargo objdump --release -- -d | head -60

clean:
	cargo clean
