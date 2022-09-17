---
title: "Data Transfer"
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

## Allocating data with buffers

OpenCL allocates space in memory *on a device* in **buffers**. 
