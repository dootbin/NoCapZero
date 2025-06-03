#ifndef GPU_H618_H
#define GPU_H618_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

/* H618 GPU Hardware Definitions */
#define GPU_BASE_ADDR      0x01800000
#define GPU_IRQ_NUM        97

/* GPU Control Registers */
#define GPU_CTRL_REG       0x000
#define GPU_STATUS_REG     0x034
#define GPU_CMD_REG        0x030
#define GPU_IRQ_STATUS     0x02C
#define GPU_IRQ_CLEAR      0x024
#define GPU_IRQ_MASK       0x028

/* Memory Management */
#define GPU_MMU_BASE       0x2000
#define GPU_AS0_BASE       0x2400

/* Job Submission */
#define GPU_JS0_BASE       0x1800

/* Power Management */
#define GPU_PWR_KEY        0x050
#define GPU_PWR_OVERRIDE   0x054

/* Our GPU device structure */
struct gpu_device {
    void *regs;
    int irq;
    bool initialized;
    uint32_t features;
};

/* Basic operations */
int gpu_init(struct gpu_device *dev, void *base, int irq);
void gpu_cleanup(struct gpu_device *dev);
int gpu_reset(struct gpu_device *dev);
int gpu_submit_job(struct gpu_device *dev, void *job);

/* Register access */
static inline uint32_t gpu_read32(struct gpu_device *dev, uint32_t offset)
{
    return *(volatile uint32_t *)((char *)dev->regs + offset);
}

static inline void gpu_write32(struct gpu_device *dev, uint32_t offset, uint32_t value)
{
    *(volatile uint32_t *)((char *)dev->regs + offset) = value;
}

#endif /* GPU_H618_H */