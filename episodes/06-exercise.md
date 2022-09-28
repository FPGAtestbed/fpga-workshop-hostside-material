---
title: "Hostside exercise"
teaching: 20
exercises: 1
---

Now you're going to write your own hostside code to run the kernel you wrote earlier. Use the saxpy example as a template and modify it to fit the sum reduction kernel. Things you'll want to think about:

- Kernel arguments in the `KernelFunctor`
- Type, size and number of buffers required
- What buffers need to be transferred and when
