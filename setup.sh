#!/bin/bash
# ============================================================
# my-os: macOS 环境搭建脚本
# 从零开始，在 RISC-V 上构建自己的操作系统
# ============================================================
# 用法: chmod +x setup.sh && ./setup.sh

set -e

echo "=============================="
echo "  my-os 开发环境搭建"
echo "=============================="
echo ""

# --- 检查 Homebrew ---
if ! command -v brew &> /dev/null; then
    echo "[1/5] 安装 Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "[1/5] Homebrew ✓"
fi

# --- 安装 QEMU ---
if ! command -v qemu-system-riscv64 &> /dev/null; then
    echo "[2/5] 安装 QEMU..."
    brew install qemu
else
    echo "[2/5] QEMU ✓ ($(qemu-system-riscv64 --version | head -1))"
fi

# --- 安装/检查 Rust ---
if ! command -v rustc &> /dev/null; then
    echo "[3/5] 安装 Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
else
    echo "[3/5] Rust ✓ ($(rustc --version))"
fi

# --- 添加 RISC-V target ---
echo "[4/5] 添加 RISC-V 编译目标..."
rustup target add riscv64gc-unknown-none-elf
rustup component add llvm-tools-preview

# --- 安装 cargo-binutils ---
echo "[5/5] 安装 cargo-binutils..."
cargo install cargo-binutils 2>/dev/null || echo "  已安装"

echo ""
echo "=============================="
echo "  环境就绪！"
echo "=============================="
echo ""
echo "下一步: 创建项目"
echo "  mkdir my-os && cd my-os"
echo "  按照 MILESTONES.md 开始第一个里程碑"
echo ""
