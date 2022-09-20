---
title: "Data Transfer and Memory Management"
teaching: -1
exercises: 0
---

:::::::::::::::::::::::::::::::::::::: questions 

- Why do we need to transfer data?
- How do we describe *where* data currently is?
- How can we transfer data between host and device?

::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: objectives

- Be able to address memory on both host and device
- Be able to transfer data between host and device
- Understand the performance implications of data transfer

::::::::::::::::::::::::::::::::::::::::::::::::

## Why do we need to transfer data?

Remember, most[^1] OpenCL devices have memory spaces separate from the main memory used by the CPU (aka **host memory**), so for the device to access some piece of data currently on the host, it must be transferred to the **device memory**. Since there are two separate memory spaces, we also need to be able to independently allocate memory in each space.

[1]: Some accelerators, such as graphics units within CPUs, share memory spaces with the CPU. In those cases main memory can usually be addressed directly from the device. Both Nvidia and AMD GPUs also provide software abstractions of "unified memory" where the device and host appear to access the same memory space and the runtime transfers data automatically but this can lead to inefficient data transfer patterns.

## Allocating data with buffers

OpenCL allocates space in device memory in abstractions of arrays called **buffers**. Recall our saxpy program:

```cpp
cl::Buffer x_d(context, CL_MEM_READ_ONLY, sizeof(double) * N, NULL, &err);
cl::Buffer y_d(context, CL_MEM_READ_ONLY, sizeof(double) * N, NULL, &err);
cl::Buffer out_d(context, CL_MEM_WRITE_ONLY, sizeof(double) * N, NULL, &err);
```

Here we have create two input buffers `x_d` and `y_d` and one output buffer `out_d`, all of size $N$ doubles. Note we have suffixed each variable with `_d` to signify that these are **deviceside buffers**. We pass the OpenCL context so it understands which device we wish to access and flags to indicate whether we need to read or write to these memory spaces from the device. OpenCL can allocate hostside memory mapped to each buffer like so:

```cpp
double *x_h = (double *)queue.enqueueMapBuffer(x_d, CL_TRUE, CL_MAP_WRITE, 0, sizeof(double) * N);
double *y_h = (double *)queue.enqueueMapBuffer(y_d, CL_TRUE, CL_MAP_WRITE, 0, sizeof(double) * N);
double *out_h = (double *)queue.enqueueMapBuffer(out_d, CL_TRUE, CL_MAP_WRITE | CL_MAP_READ, 0, sizeof(double) * N);
```

Again notice our use of the `_h` suffix to signify that these pointer point to hostside data. This is a useful convention when dealing with different memory spaces.

## Transferring data between host and device

Data can be transferred between device and host using a migrate task `queue.enqueueMigrateMemObjects`:

```cpp
queue.enqueueMigrateMemObjects({x_d, y_d},0);
...
queue.enqueueMigrateMemObjects({out_d}, CL_MIGRATE_MEM_OBJECT_HOST);
```

Because we've already done some work in setting up buffers and mapping those to hostside memory, the data transfer calls are relatively simple and less error-prone as a result. It is still possible to transfer data without mapping but more care must be taken in each transfer call.
