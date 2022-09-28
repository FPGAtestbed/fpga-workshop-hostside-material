---
title: "OpenCL"
teaching: 15
exercises: 1
---

:::::::::::::::::::::::::::::::::::::: questions 

- What is OpenCL?
- How does OpenCL let me program accelerators?
- How do I find and connect to attached OpenCL devices?

::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: objectives

- Understand OpenCL and its use in programming accelerators
- Be able to describe main components of an OpenCL program
- Understand contexts, devices, programs and queues
- Be able to request a specific device from the OpenCL runtime

::::::::::::::::::::::::::::::::::::::::::::::::

## OpenCL

OpenCL is a framework for managing accelerators, initially developed in 2009, and is maintained by the Khronos Group. The components particularly relevant to programming FPGAs are:

1. A language for describing computational kernels in a (nearly) device-agnostic way (not used in this workshop!)
2. A runtime which interfaces with specific devices attached to the machine running an OpenCL code
3. An API for programmatically finding attached devices, transferring data, and launching kernels

We will be using the [C++ bindings for OpenCL](https://github.khronos.org/OpenCL-CLHPP/), a wrapper around the more traditional C API which makes OpenCL fit better into C++ code. This is sometimes referred to as **opencl-clhpp**.

## The OpenCL Runtime

Each device vendor that supports OpenCL provides a runtime that can interface with OpenCL programs, so Intel, Nvidia, AMD, Xilinx and others all provide runtimes for their devices. The associated runtime must be installed in order for your OpenCL code to use a particular device. Because of the use of a "runtime" instead of a more traditional library, and OpenCL code should not require recompilation to interface with different devices; the differences are handled by the runtime itself. In this workshop we will be using the runtime supplied as part of Xilinx's Vitis toolchain which allows us to interface with attached FPGAs (although we will mainly be using Xilinx's simulation mode in this workshop).

In general OpenCL runtimes provide a few functions to a running OpenCL program:

1. Finding and accessing all devices attached to the running computer
2. Handling any data transfer and memory management requests
3. Managing queues (i.e. kernel launches, events, and synchronisation)
4. Optionally compiling OpenCL kernels during runtime (this is *not* the case for FPGAs however)

## Anatomy of an OpenCL program

The saxpy algorithm from the previous section can be written as an HLS kernel like so:

```cpp
void saxpy(double *x, double *y, double *out, double a, int N) {
  for (int i = 0; i < N; i++) {
    out[i] = a*x[i]+y[i];
  }
}
```

While this might seem like a simple function, it's only the **kernel**, the function that is run on the device. The hostside code can look significantly more complex, mainly due to the necessary complexity of managing devices, data transfers and kernel launches. Here's a minimal, complete example of hostside code capable of running the above kernel on a device:

```cpp
#include <string>
#include <vector>
#include <iostream>
#include <host_support.h>
#include <CL/cl2.hpp>

const int N = 1000;
const double a = 2.0;
const int BUFFER_SIZE = N*sizeof(double);
const std::string XCLBIN_FILE = "saxpy.xclbin";

int main(int argc, const char **argv)
{
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

  // LOAD KERNEL
  cl::KernelFunctor<
    cl::Buffer, cl::Buffer, cl::Buffer, double, int
  > saxpy_kernel = cl::Kernel(program, "saxpy");

  // create device-side buffers (i.e. allocate device memory)
  cl::Buffer x_d(context, CL_MEM_READ_ONLY, BUFFER_SIZE, NULL, &err);
  cl::Buffer y_d(context, CL_MEM_READ_ONLY, BUFFER_SIZE, NULL, &err);
  cl::Buffer out_d(context, CL_MEM_WRITE_ONLY, BUFFER_SIZE, NULL, &err);
      
  // CREATE CORRESPONDING HOST-SIDE BUFFERS
  double *x_h = (double *)queue.enqueueMapBuffer(x_d, CL_TRUE, CL_MAP_WRITE, 0, BUFFER_SIZE);
  double *y_h = (double *)queue.enqueueMapBuffer(y_d, CL_TRUE, CL_MAP_WRITE, 0, BUFFER_SIZE);
  double *out_h = (double *)queue.enqueueMapBuffer(out_d, CL_TRUE, CL_MAP_WRITE | CL_MAP_READ, 0, BUFFER_SIZE);
      
  // LOAD DATA INTO HOST-SIDE
  for(int i = 0; i < N; i++) {
      x_h[i] = i/3.0;
      y_h[i] = i/2.0;
  }

  // TRANSFER DATA TO DEVICE
  queue.enqueueMigrateMemObjects({x_d, y_d},0);

  // QUEUE KERNEL
  saxpy_kernel(cl::EnqueueArgs(queue, cl::NDRange(1), cl::NDRange(1)), x_d, y_d, out_d, a, N);

  // SYNCHRONISE
  queue.finish();

  // TRANSFER DATA TO HOST
  queue.enqueueMigrateMemObjects({out_d}, CL_MIGRATE_MEM_OBJECT_HOST);

  // SYNCHRONISE AGAIN
  queue.finish();

  bool kernel_worked = true;
  for(int i = 0; i < N; i++) {
    if(out_h[i] != a*x_h[i] + y_h[i]) {
      kernel_worked = false;
      break;
    }
  }

  if (kernel_worked) {
    std::cout << "It worked!" << std::endl;
  } else {
    std::cout << "Something went wrong..." << std::endl;
  }

  return 0;
}
```

If you've seen OpenCL code before this should be relatively familiar with one exception: for codes targeting CPU and GPU the source code for the kernel is usually loaded and compiled by the runtime (at runtime); here, we compile the kernel separately using Xilinx tools and load the pre-compiled binary (with filetype `.xclbin`). We have also not provided much error handling for simplicity so please do not use this code in production code!

If you haven't seen OpenCL code before, don't worry, we'll break this example down over the next few sections into the following major pieces:

- OpenCL initialisation
  - How to find valid, connected OpenCL devices?
  - What are contexts, programs and queues and how do we set them up?
- Data transfer and memory management
  - What are buffers?
  - How can I allocate memory on the device?
  - How can I transfer data to and from the device?
- Kernel launching and synchronisation
  - How can I load my pre-compiled kernel?
  - How can I launch kernels?
  - How can I synchronise host and device?

While is might seem like OpenCL requires a lot of boilerplate, it's all necessary. Much of it only has to happen once in a whole code so while the boilerplate is *most* of the code in this example, in larger, real codes the boilerplate is a less significant part of the codebase.

## OpenCL Initialisation

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

Finally, a **queue** or **command queue** is OpenCL's way of organising data transfer requests, kernel launches, event handling, etc, essentially any tasks that could require a specific order. Remember devices are mostly asynchronous with respect to the host so a queue is required to ensure certain tasks happen in the expected order. The host can synchronise a queue, waiting until the queue has finished or waiting for a specific event to be handling (e.g. signalling the end of a particular kernel). There can be multiple queues at any one time, allowing a programmer to, for example, queue both a kernel launch and a data transfer task at the same time to overlap their runtimes. This is advanced use of queues however and we will only be using a single queue in this workshop.

::: challenge

## Documentation Challenge

The `initialiseDevice` function takes care of most of the OpenCL boilerplate involving interfacing with the runtime, asking for a list of available devices, finding a matching device, loading the binary file and creating the context and program associated with the device and binary. You can read through the source for the host_support library after the workshop[^1] but in this challenge we'd like you to head to the OpenCL C++ documentation (see Resources section at the end of the section) and just find the documentation for:

- `cl::Context`
- `cl::Platform::get(...)`
- `cl::CommandQueue`

The point of this exercise is just to ensure you can find what you're looking for in the OpenCL C++ documentation.

[^1]: It's a short and easily read library I promise!

:::

## Resources

- [OpenCL C++ Bindings](https://github.khronos.org/OpenCL-CLHPP/)
  - This documentation is a little hard to read and sometimes incomplete. It may be that reading the source code of the library is easier.
- [OpenCL 2.1 Reference Pages](https://man.opencl.org/)
  - Only documents the C API but can be more informative than the C++ Bindings documentation

::::::::::::::::::::::::::::::::::::: keypoints 

- OpenCL is a framework for managing accelerators
- The OpenCL runtime provides functions for interfacing with accelerators
- An OpenCL context is a structure containing global information about the OpenCL state
- A program is a collection of compiled kernels
- A device is a connected device capable of running an OpenCL kernel
- A queue is an ordered list of tasks or events to be run on the device
- Kernels are loaded from programs and can be wrapped in KernelFunctors for ease of calling

::::::::::::::::::::::::::::::::::::::::::::::::
