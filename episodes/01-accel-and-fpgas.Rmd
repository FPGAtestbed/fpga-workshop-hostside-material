---
title: "Introduction to Accelerators"
teaching: 15
exercises: 0
---

:::::::::::::::::::::::::::::::::::::: questions 

- What is an accelerator?

::::::::::::::::::::::::::::::::::::::::::::::::

::::::::::::::::::::::::::::::::::::: objectives

- Understand what accelerators are
- Understand what kernels are in the context of accelerators
- Understand what FPGAs are and why they're useful

::::::::::::::::::::::::::::::::::::::::::::::::

## What are accelerators?

Accelerators are **devices** which can be connected to computers (aka **hosts**) and used to perform certain kinds of computation much faster than CPUs. The most common accelerators in HPC systems today are graphical processing units (GPUs) which were originally developed to process large numbers of graphics primitives (e.g. pixels, triangles and lines) for rendering 3D computer graphics. Due to their history, their particular strength is being able to perform a large number of calculations in parallel. State of the art GPUs have over 10,000 processing units, much larger than the typical 100 or so cores found in most HPC-grade CPUs, making them particularly suitable for applications where one operation is applied to many pieces of data, such as many image processing algorithms.

![](fig/host_device.png)

The key things to note about accelerators generally are:

1. They typically have separate memory to main memory
  - Data must be transferred to/from device
  - Performance can be affected by slow data transfer
2. They can compute asynchronously
  - The host can continue doing work
  - Care must be taken to synchronise at key points

During this section we will be using the term *device* to refer to some computing device or accelerator attached to a computer, which we will call the *host*. While code on the host is typically structured in terms of functions and classes, accelerator devices typically run what are called **kernels**.

## What is a kernel?

In the context of accelerators, a **kernel** is a core piece of computation which is run on a device. It usually performs the same algorithm on a large amount of data. Kernels are typically written in some device-specific language different from the language used to program the host, for example CUDA and HIP for GPUs, or Vitis HLS and Intel OpenCL for FPGAs. Kernels can be parallelised through having many cores performing the same algorithm on a large data structure at the same time (such as on a GPU) or by **pipelining** an algorithm

## What is an FPGA?

The field-programmable gate array (FPGA) is another kind of accelerator which is unlike both CPUs and GPUs. To understand how it differs, and why it's useful, it's instructive to recap how a CPU works at a fundamental level.

CPUs (and GPUs) are given a description of a computation in terms of a list of instructions, each of which must be fetched from storage, decoded and then executed by a relevant unit of the CPU. For example addition, binary OR, if statements, and movement of data all have specific instructions or groups of instructions that tell the computing units to perform that operation. Each type of instruction is handled by different subunits in the CPU, for example a floating-point unit (FPU) for non-integer arithmetic. Within each of the subunits there is circuitry which actually performs the operation on given inputs. Let's look at an example to understand how these instructions can be described "in hardware".

Take the example algorithm saxpy or "single-precision $a$ times $x$ plus $y$":
```
for (int i=0; i<N; ++i) {
  result[i] = a * x[i] + y[i];
}
```

The corresponding pseudocode listing the low-level instructions roughly look like:

```
move a, x[i] and y[i] into registers within the CPU
multiply a and x[i] in FPU, store result in register
add y[i] to previous result in FPU, store result in register
... handle loop
```

The key computations happening in this algorithm are the multiplication and addition, each which are performed by some piece of circuitry within the FPU. We could think about the entire algorithm in terms of just the circuitry like so:

![](fig/saxpy_dataflow.png)

This is exactly what FPGAs are designed to do: **represent algorithms as data flowing through pieces of circuitry**. This is what is meant by implementing an algorithm "in hardware". Why is this useful? The fetch-decode-execute cycle itself consumes both time and energy so an algorithm described as data flowing through circuitry wastes no time or energy handling instructions; it's all devoted to the computation actually being carried out. What makes FPGAs particularly useful for general purpose work is that they are able to change the implemented circuit dynamically as required by the programmer.

### FPGA Structure

The structure of the FPGA roughly looks like:

![](fig/FPGA_structure.png)

The **fabric** is made up of **configurable logic blocks** which are the basic building blocks of any circuit implemented on the FPGA. Along with these basic blocks, there can be other blocks like pieces of memory, I/O buffers, DSP blocks and other, large-scale components which interface with the external world, like ethernet or PCEi controllers. Most of these extra blocks can be used without input from the FPGA programmer so all we really need to care about for this introductory workshop is having the concept of blocks forming circuits which represent the dataflow of our algorithms.

Blocks that *are* relevant to our later optimisation session are the local memory blocks: pieces of RAM embedded in the fabric that can hold small amounts of data. These can generally be thought of as caches or even registers and can be accessed much more quickly than the large device memory.

::::::::::::::::::::::::::::::::::::: keypoints 

- Accelerators are devices used to offload particular kinds of computation
- FPGAs are a type of accelerator that can implement algorithms as circuits

::::::::::::::::::::::::::::::::::::::::::::::::
