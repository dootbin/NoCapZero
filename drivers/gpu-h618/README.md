# H618 GPU Driver

Bare-metal GPU driver for Allwinner H618 SoC (Orange Pi Zero 2W).

## Building

### Cross-compilation for ARM64
```bash
export CROSS_COMPILE=aarch64-linux-gnu-
make
```

### Syntax check only
```bash
make check
```

## Integration

This driver provides low-level GPU control for the H618 platform. It maps GPU registers at physical address 0x01800000 and provides basic initialization and job submission interfaces.

## Files

- `include/gpu_h618.h` - Public API and register definitions
- `src/gpu_init.c` - Hardware initialization and control
- `Makefile` - Build configuration