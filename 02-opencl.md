---
title: "OpenCL"
teaching: -1
exercises: 0
---

:::::::::::::::::::::::::::::::::::::: questions 

- What is OpenCL?
- How does OpenCL let me program accelerators?

::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: objectives

- Understand OpenCL and its use in programming accelerators
- Be able to describe main components of an OpenCL program

::::::::::::::::::::::::::::::::::::::::::::::::

## OpenCL

OpenCL is a framework for managing accelerators, initially developed in 2009, and is maintained by the Khronos Group. The components particularly relevant to programming FPGAs are:

1. A language for describing computational kernels in a (nearly) device-agnostic way
2. A runtime which interfaces with specific devices attached to the machine running an OpenCL code
3. An API for programmatically finding attached devices, transferring data, and launching kernels

## OpenCL C

This will not be used in this workshop. See [Intel's FPGA resources](https://www.intel.com/content/www/us/en/software/programmable/sdk-for-opencl/overview.html) for more information on using OpenCL C/C++ to write kernels.

We will be using Xilinx's C-based Vitis HLS language in this workshop.

## Anatomy of an OpenCL program

The saxpy algorithm from the previous section can be written as an HLS kernel like so:

```cpp
void saxpy(double *x, double *y, double *out, double a, int N) {
  for (int i = 0; i < N; i++) {
    out[i] = a*x[i]+y[i];
  }
}
```

While this might seem like a simple function, it's only the **kernel**, the function that is run on the device. The hostside code can look significantly more complex, mainly due to the complexity of managing devices, data transfers and kernel launches. Here's a minimal, complete example of hostside code capable of running the above kernel on a device:

```cpp
#include <string>
#include <vector>
#include <host_support.h>
#include <CL/cl2.hpp>

const int N = 1000;
const double a = 2.0;
const int BUFFER_SIZE = N*sizeof(double);
const std::string XCLBIN_FILE = "example_kernel.xclbin";

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

  // CREATE DEVICE-SIDE BUFFERS (i.e. allocate device memory)
  cl::Buffer x_d(context, CL_MEM_READ_ONLY, sizeof(double) * N, NULL, &err);
  cl::Buffer y_d(context, CL_MEM_READ_ONLY, sizeof(double) * N, NULL, &err);
  cl::Buffer out_d(context, CL_MEM_WRITE_ONLY, sizeof(double) * N, NULL, &err);
      
  // CREATE CORRESPONDING HOST-SIDE BUFFERS
  double *x_h = (double *)queue.enqueueMapBuffer(x_d, CL_TRUE, CL_MAP_WRITE, 0, sizeof(double) * N);
  double *y_h = (double *)queue.enqueueMapBuffer(y_d, CL_TRUE, CL_MAP_WRITE, 0, sizeof(double) * N);
  double *out_h = (double *)queue.enqueueMapBuffer(out_d, CL_TRUE, CL_MAP_WRITE | CL_MAP_READ, 0, sizeof(double) * N);
      
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

  return 0;
}
```

We'll break this down over the next few sections into the following major pieces:

- OpenCL initialisation
  - How to find valid, connected OpenCL devices?
  - What are contexts, programs and queues and how do we set them up?
  - How do I compile a kernel?
  - How can I load my kernel?
- Data transfer and memory management
  - What are buffers?
  - How can I allocate memory on the device?
  - How can I transfer data to and from the device?
- Kernel launching and synchronisation
  - How can I launch kernels?
  - How can is synchronise host and device?
