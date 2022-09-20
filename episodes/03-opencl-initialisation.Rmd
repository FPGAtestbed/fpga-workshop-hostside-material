---
title: "OpenCL Initialisation"
teaching: -1
exercises: 0
---

:::::::::::::::::::::::::::::::::::::: questions 

- What are OpenCL's contexts, programs, devices and queues?
- How do I find and connect to attached OpenCL devices?
- How can I compile and/or load a kernel

::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: objectives

- Understand contexts, programs and queues
- Be able to request a specific device from the OpenCL runtime
- Be able to pre-compile and load kernels

::::::::::::::::::::::::::::::::::::::::::::::::

Let's breakdown the initialisation step of the minimal saxpy code from the previous section:

```cpp
// LOAD OPENCL DEVICE + BINARY FILE
cl::Context* context_p;
cl::Program* program_p;
std::vector<cl::Device> devices;
std::tie(program_p, context_p, devices)=initialiseDevice("Xilinx", "u280", XCLBIN_FILE);
cl::Device device = devices[0]; // Choose first device from results
cl::Context context = *context_p;
cl::Program program = *program_p;
cl_int err;
cl::CommandQueue queue(context, device, CL_QUEUE_PROFILING_ENABLE, &err);
```

## Contexts, programs, devices and queues

The **context** is an OpenCL structure containing global information about the currently running code, such as which devices are currently being used. For the most part, you can set it up in the initialisation stage and forget about it. The initialisation here is handled by the `initialiseDevice` function provided by the `host_support` library.

A **program** is a collection of kernels and device functions (that are functions that will only be run on the devices). OpenCL codes targeting CPUs and GPUs may compile this program from a provided source during runtime but on FPGAs it is more standard to precompile the kernel and then load the `.xclbin` file. Here, the loading of the program is again handled by `initialiseDevice`.

A **device** is any device capable of running an OpenCL kernel. Each device identifies itself to the OpenCL API via a string containing the vendor and type of device, so here we can use the `initialiseDevice` function (again) to find and fetch details of all devices with identity string matching that of the "u280" FPGA made by "Xilinx". Since `devices` is a vector, we take the first device found. If OpenCL cannot find any device with these identifiers, `devices` will be empty and the program will crash so, again, please do not use this code in production.

Finally, a **queue** is OpenCL's way of organising data transfer requests, kernel launches, event handling, etc, essentially any tasks that could require a specific order. Remember devices are mostly asynchronous with respect to the host so a queue is required to ensure certain tasks happen in the expected order. The host can synchronise a queue, waiting until the queue has finished or waiting for a specific event to be handling (e.g. signalling the end of a particular kernel). There can be multiple queues at any one time, allowing a programmer to, for example, queue both a kernel launch and a data transfer task at the same time to overlap their runtimes. This is advanced use of queues however and we will only be using a single queue in this workshop.

## Loading a kernel

OpenCL provides a useful `KernelFunctor` class which wraps a kernel and presents it as if it were a regular function. Alternatively, you can use a `Kernel` object directly and set arguments manually via `setArg` however we have found this to be unnecessarily complex and error-prone. We recommend using `KernelFunctor` where possible.

Let's compare the function signature for the kernel `saxpy`:

```
void saxpy(double *x, double *y, double *out, double a, int N) {
```

with its corresponding `KernelFunctor`:

```
cl::KernelFunctor<
  cl::Buffer, cl::Buffer, cl::Buffer, double, int
> saxpy_kernel = cl::Kernel(program, "saxpy");
```

We tell OpenCL we want to load the kernel `saxpy` from the program loaded during initialisation and then we wrap that kernel in a `KernelFunctor`. Notice the *template* arguments to `KernelFunctor` correspond to the *function* arguments of the kernel `saxpy` where array pointer arguments correspond to `cl::Buffer`s (more on these later). Calling the kernel then looks somewhat like calling a function called `saxpy_kernel`:

```
saxpy_kernel(cl::EnqueueArgs(queue, cl::NDRange(1), cl::NDRange(1)), x_d, y_d, out_d, a, N);
```

::::::::::::::::::::::::::::::::::::: keypoints 

- An OpenCL context is a structure containing global information about the OpenCL state
- A program is a collection of compiled kernels
- A device is a valid OpenCL device capable of running a kernel
- A queue is an ordered list of tasks to be performed on or by the device
- Kernels are loaded from programs and can be wrapped in KernelFunctors for ease of calling

::::::::::::::::::::::::::::::::::::::::::::::::
