# Bare-metal GPU driver for Allwinner H618
# Orange Pi Zero 2W GPU support

CROSS_COMPILE ?= aarch64-linux-gnu-
CC = $(CROSS_COMPILE)gcc
AR = $(CROSS_COMPILE)ar

CFLAGS = -Wall -Wextra -O2 -fno-builtin -ffreestanding
CFLAGS += -march=armv8-a -mtune=cortex-a53
CFLAGS += -Iinclude

SRCS = src/gpu_init.c
OBJS = $(SRCS:.c=.o)

TARGET = libgpu_h618.a

all: $(TARGET)

$(TARGET): $(OBJS)
	$(AR) rcs $@ $^

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS) $(TARGET)

check:
	gcc -fsyntax-only -Wall -Wextra -Iinclude $(SRCS)

.PHONY: all clean check