---
title: "Kernel Management"
teaching: 10
exercises: 0
---

:::::::::::::::::::::::::::::::::::::: questions 

- How do we load pre-compiled kernels?
- How do we run and synchronise kernels?

::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: objectives

- Be able to load and call a kernel in an FPGA-accelerated program

::::::::::::::::::::::::::::::::::::::::::::::::

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

We tell OpenCL we want to load the kernel `saxpy` from the program loaded during initialisation and then we wrap that kernel in a `KernelFunctor`. Notice the *template* arguments to `KernelFunctor` correspond to the *function* arguments of the kernel `saxpy` where array pointer arguments correspond to `cl::Buffer`s.

## Calling a kernel

Recall from our saxpy example the piece of our hostside code that deals with the calling and synchronisation of the kernel:

```
// QUEUE KERNEL
saxpy_kernel(cl::EnqueueArgs(queue, cl::NDRange(1)), x_d, y_d, out_d, a, N);

// SYNCHRONISE
queue.finish();
```

What we're doing here is submitting the previously loaded saxpy kernel to the main queue created during the initialisation stage. Just like calling a regular function we provide the kernel with the arguments we want it to operate on, `x_d, y_d, out_d, a, N`, but we also provide an `EnqueueArgs`. This structure is OpenCL's way of encapsulating how a kernel should be run, with the first argument describing which queue the kernel should be submitted to and the second describing how many copies of the kernel should be run. This second parameter is more important for GPU kernels and for FPGA development the range is usually set to $1$.

Once the kernel is submitted, control is given back to the CPU running the hostside code, that is the kernel runs **asynchronously**. In this example, our CPU isn't going to do anything while the kernel is running so we use `queue.finish()` to wait for the queue to end. If we're submitting many kernels and data transfer tasks to the queue we can also submit events to the queue which we can specifically synchronise.

::::::::::::::::::::::::::::::::::::: keypoints 

- OpenCL provides a `KernelFunctor` wrapper that makes calling kernels (nearly) as simple as calling a function
- Kernels run asynchronously with respect to the host
- Queues must be synchronised to ensure all data transfer or computation has completed before relevant data is accessed

::::::::::::::::::::::::::::::::::::::::::::::::
