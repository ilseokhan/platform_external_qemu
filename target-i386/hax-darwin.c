/*
** Copyright (c) 2011, Intel Corporation
**
** This software is licensed under the terms of the GNU General Public
** License version 2, as published by the Free Software Foundation, and
** may be copied, distributed, and modified under those terms.
**
** This program is distributed in the hope that it will be useful,
** but WITHOUT ANY WARRANTY; without even the implied warranty of
** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
** GNU General Public License for more details.
*/

/* HAX module interface - darwin version */
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/ioctl.h>

#include "target-i386/hax-i386.h"
hax_fd hax_mod_open(void)
{
    int fd = open("/dev/HAX", O_RDWR);

    if (fd == -1)
    {
        dprint("Failed to open the hax module\n");
        return -errno;
    }

    return fd;
}

int hax_populate_ram(uint64_t va, uint32_t size)
{
    int ret;
    struct hax_alloc_ram_info info;

    if (!hax_global.vm || !hax_global.vm->fd)
    {
        dprint("Allocate memory before vm create?\n");
        return -EINVAL;
    }

    info.size = size;
    info.va = va;
    ret = ioctl(hax_global.vm->fd, HAX_VM_IOCTL_ALLOC_RAM, &info);
    if (ret < 0)
    {
        dprint("Failed to allocate %x memory\n", size);
        return ret;
    }
    return 0;
}

int hax_set_phys_mem(hwaddr start_addr, ram_addr_t size, ram_addr_t phys_offset)
{
    struct hax_set_ram_info info, *pinfo = &info;
    int ret;
    ram_addr_t flags = phys_offset & ~TARGET_PAGE_MASK;

    /* We look for the  RAM and ROM only */
    if (flags >= IO_MEM_UNASSIGNED)
        return 0;

    if ( (start_addr & ~TARGET_PAGE_MASK) || (size & ~TARGET_PAGE_MASK))
    {
        dprint("set_phys_mem %x %lx requires page aligned addr and size\n", start_addr, size);
        exit(1);
        return -1;
    }

    info.pa_start = start_addr;
    info.size = size;
    info.va = (uint64_t)qemu_get_ram_ptr(phys_offset);
    info.flags = (flags & IO_MEM_ROM) ? 1 : 0;

    ret = ioctl(hax_global.vm->fd, HAX_VM_IOCTL_SET_RAM, pinfo);
    if (ret < 0)
    {
        dprint("has set phys mem failed\n");
        exit(1);
    }
    return ret;
}

int hax_capability(struct hax_state *hax, struct hax_capabilityinfo *cap)
{
    int ret;

    ret = ioctl(hax->fd, HAX_IOCTL_CAPABILITY, cap);
    if (ret == -1)
    {
        dprint("Failed to get HAX capability\n");
        return -errno;
    }

    return 0;
}

int hax_mod_version(struct hax_state *hax, struct hax_module_version *version)
{
    int ret;

    ret = ioctl(hax->fd, HAX_IOCTL_VERSION, version);
    if (ret == -1)
    {
        dprint("Failed to get HAX version\n");
        return -errno;
    }

    return 0;
}

static char *hax_vm_devfs_string(int vm_id)
{
    char *name;

    if (vm_id > MAX_VM_ID)
    {
        dprint("Too big VM id\n");
        return NULL;
    }

    name = g_strdup("/dev/hax_vm/vmxx");
    if (!name)
        return NULL;
    sprintf(name, "/dev/hax_vm/vm%02d", vm_id);

    return name;
}

static char *hax_vcpu_devfs_string(int vm_id, int vcpu_id)
{
    char *name;

    if (vm_id > MAX_VM_ID || vcpu_id > MAX_VCPU_ID)
    {
        dprint("Too big vm id %x or vcpu id %x\n", vm_id, vcpu_id);
        return NULL;
    }

    name = g_strdup("/dev/hax_vmxx/vcpuyy");
    if (!name)
        return NULL;

    sprintf(name, "/dev/hax_vm%02d/vcpu%02d", vm_id, vcpu_id);

    return name;
}

int hax_host_create_vm(struct hax_state *hax, int *vmid)
{
    int ret;
    int vm_id = 0;

    if (hax_invalid_fd(hax->fd))
        return -EINVAL;

    if (hax->vm)
        return 0;

    ret = ioctl(hax->fd, HAX_IOCTL_CREATE_VM, &vm_id);
    *vmid = vm_id;
    return ret;
}

hax_fd hax_host_open_vm(struct hax_state *hax, int vm_id)
{
    hax_fd fd;
    char *vm_name = NULL;

    vm_name = hax_vm_devfs_string(vm_id);
    if (!vm_name)
        return -1;

    fd = open(vm_name, O_RDWR);
    g_free(vm_name);

    return fd;
}

int hax_notify_qemu_version(hax_fd vm_fd, struct hax_qemu_version *qversion)
{
    int ret;

    if (hax_invalid_fd(vm_fd))
        return -EINVAL;

    ret = ioctl(vm_fd, HAX_VM_IOCTL_NOTIFY_QEMU_VERSION, qversion);
    if (ret == -1)
    {
        dprint("Failed to notify qemu API version\n");
        return -errno;
    }

    return 0;
}

/*
 * Simply assume that the size should be bigger than the hax_tunnel,
 * since the hax_tunnel can be extended later with backward
 * compatibility.
 */
int hax_host_create_vcpu(hax_fd vm_fd, int vcpuid)
{
    int ret;

    ret = ioctl(vm_fd, HAX_VM_IOCTL_VCPU_CREATE, &vcpuid);
    if (ret < 0)
        dprint("Failed to create vcpu %x\n", vcpuid);

    return ret;
}

hax_fd hax_host_open_vcpu(int vmid, int vcpuid)
{
    char *devfs_path = NULL;
    hax_fd fd;

    devfs_path = hax_vcpu_devfs_string(vmid, vcpuid);
    if (!devfs_path)
    {
        dprint("Failed to get the devfs\n");
        return -EINVAL;
    }

    fd = open(devfs_path, O_RDWR);
    g_free(devfs_path);
    if (fd < 0)
        dprint("Failed to open the vcpu devfs\n");
    return fd;
}

int hax_host_setup_vcpu_channel(struct hax_vcpu_state *vcpu)
{
    int ret;
    struct hax_tunnel_info info;

    ret = ioctl(vcpu->fd, HAX_VCPU_IOCTL_SETUP_TUNNEL, &info);
    if (ret)
    {
        dprint("Failed to setup the hax tunnel\n");
        return ret;
    }

    if (!valid_hax_tunnel_size(info.size))
    {
        dprint("Invalid hax tunnel size %x\n", info.size);
        ret = -EINVAL;
        return ret;
    }

    vcpu->tunnel = (struct hax_tunnel *)(info.va);
    vcpu->iobuf = (unsigned char *)(info.io_va);
    return 0;
}

int hax_vcpu_run(struct hax_vcpu_state* vcpu)
{
    int ret;

    ret = ioctl(vcpu->fd, HAX_VCPU_IOCTL_RUN, NULL);
    return ret;
}

int hax_sync_fpu(CPUX86State *env, struct fx_layout *fl, int set)
{
    int ret, fd;

    fd = hax_vcpu_get_fd(env);
    if (fd <= 0)
        return -1;

    if (set)
        ret = ioctl(fd, HAX_VCPU_IOCTL_SET_FPU, fl);
    else
        ret = ioctl(fd, HAX_VCPU_IOCTL_GET_FPU, fl);
    return ret;
}

int hax_sync_msr(CPUX86State *env, struct hax_msr_data *msrs, int set)
{
    int ret, fd;

    fd = hax_vcpu_get_fd(env);
    if (fd <= 0)
        return -1;
    if (set)
        ret = ioctl(fd, HAX_VCPU_IOCTL_SET_MSRS, msrs);
    else
        ret = ioctl(fd, HAX_VCPU_IOCTL_GET_MSRS, msrs);
    return ret;
}

int hax_sync_vcpu_state(CPUX86State *env, struct vcpu_state_t *state, int set)
{
    int ret, fd;

    fd = hax_vcpu_get_fd(env);
    if (fd <= 0)
        return -1;

    if (set)
        ret = ioctl(fd, HAX_VCPU_SET_REGS, state);
    else
        ret = ioctl(fd, HAX_VCPU_GET_REGS, state);
    return ret;
}

int hax_inject_interrupt(CPUX86State *env, int vector)
{
    int ret, fd;

    fd = hax_vcpu_get_fd(env);
    if (fd <= 0)
        return -1;

    ret = ioctl(fd, HAX_VCPU_IOCTL_INTERRUPT, &vector);
    return ret;
}
