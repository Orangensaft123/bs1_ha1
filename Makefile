#!/usr/bin/make
.SUFFIXES:
.PHONY: all run pack clean

# BIN_FILES lists all binary components that will be concatenated into the final image.
# The first file MUST be the bootloader.
BIN_FILES = bootloader.bin

# --- Source and Target Files ---
SRC_C = $(wildcard *.c)
SRC_S = $(wildcard *.s)
SRC   = $(SRC_C) $(SRC_S)
HDR   = $(wildcard *.h)
OBJS  = $(SRC_C:.c=.o) $(SRC_S:.s=.o)

ELF_FILES = $(BIN_FILES:.bin=.elf)
LD_FILES = $(BIN_FILES:.bin=.ld)
KERNEL_IMG = kernel

# Package name for submission
PCK = lab-1.zip

# --- Toolchain and Flags Configuration ---

# Set the default `objcopy` tool from binutils.
OBJCOPY ?= objcopy

# Every byte counts in a 512-byte boot sector: by default the compiler keeps
# the stack 16-byte aligned (a requirement of modern ABIs, not of the BIOS),
# which wastes code on alignment arithmetic. Real mode is fine with 4 bytes.
# The BIOS loads us at a fixed address; avoid host-default PIE/GOT overhead.
CFLAGS = -m16 -c -Os -march=i686 -mpreferred-stack-boundary=2 -ffreestanding -fno-pie -Wall
LFLAGS = -m elf_i386 -z noexecstack -static -nostdlib --nmagic
AFLAGS = --32

# Check if the default compiler is clang (macOS)
IS_CLANG := $(findstring clang, $(shell $(CC) --version 2>/dev/null))

# On hosts whose default compiler is clang (macOS), build with the x86_64-elf
# cross toolchain instead. Using the same gcc on every platform matters for
# this exercise: compilers differ a lot in how compact their 16-bit code is,
# and whether your bootloader fits into its 512 bytes should not depend on
# your host OS. On macOS with Homebrew, install the toolchain with:
# brew install x86_64-elf-gcc x86_64-elf-binutils
ifneq ($(strip $(IS_CLANG)),)
    CC      = x86_64-elf-gcc
    AS      = x86_64-elf-as
    LD      = x86_64-elf-ld
    OBJCOPY = x86_64-elf-objcopy

    # Detect a missing toolchain now, so that the build can explain itself
    # instead of failing with a bare "command not found".
    ifeq ($(shell command -v x86_64-elf-gcc 2>/dev/null),)
        MISSING_TOOLCHAIN = yes
    endif
endif

# --- Build Rules ---

# Default target
all: $(KERNEL_IMG)

# The bootloader requires its own C object file and the assembly entry point.
bootloader.elf: bootloader.o boot.o bootloader.ld
	$(LD) $(LFLAGS) -T bootloader.ld -o $@ bootloader.o boot.o

# Generic rule for any additional stages (e.g., stage2.elf).
# It links a single object file (e.g., stage2.o) with its linker script.
# This rule will NOT be used for 'bootloader.elf' because a specific rule exists above.
%.elf: %.o %.ld
	$(LD) $(LFLAGS) -T$*.ld -o $@ $<

# Convert the ELF file to a flat binary.
%.bin: %.elf
	$(OBJCOPY) -O binary $^ $@

# Create the final kernel image file for QEMU.
$(KERNEL_IMG): $(BIN_FILES)
	cat $^ > $@

# Rule to compile C files into object files.
%.o: %.c $(HDR) | toolchain
	$(CC) $(CFLAGS) -o $@ $<

# Rule to assemble assembly files into object files.
%.o: %.s | toolchain
	$(AS) $(AFLAGS) -o $@ $<

# Guard: explain a missing cross toolchain in plain words. Order-only
# prerequisite of the compile rules, so `make clean`/`make pack` still work.
.PHONY: toolchain
toolchain:
ifeq ($(MISSING_TOOLCHAIN),yes)
	@echo '***'
	@echo '*** Die Cross-Toolchain (x86_64-elf-gcc) wurde nicht gefunden.'
	@echo '*** Auf macOS installieren Sie sie bitte einmalig mit:'
	@echo '***'
	@echo '***     brew install qemu x86_64-elf-gcc x86_64-elf-binutils'
	@echo '***'
	@echo '*** Danach funktionieren alle make-Befehle wie gewohnt.'
	@exit 1
else
	@:
endif

# --- Utility Targets ---

# Run the kernel in QEMU
run: $(KERNEL_IMG)
	qemu-system-x86_64 -drive format=raw,file=$(KERNEL_IMG)

# Create a zip archive for submission.
pack: clean
	zip $(PCK) Makefile $(SRC) $(HDR) $(LD_FILES)

# Clean up generated files.
clean:
	rm -f $(OBJS) $(ELF_FILES) $(BIN_FILES) $(KERNEL_IMG) $(PCK)
