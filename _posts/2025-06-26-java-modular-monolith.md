---
layout: post
title: Java Modular Monolith
date: 2025-06-26 17:27 +0200
categories: [Architecture]
tags: [Modular Monolith, Java, Architecture]
description: This Post is about the concept of a Modular Monolith in Java, its architecture, communication patterns, and the benefits it brings to software development.
---
# Modular Monolith in Java
In this post, we will explore the concept of a Modular Monolith in Java. We will discuss its architecture, communication patterns, and the benefits it brings to software development.

## What is a Modular Monolith?
A Modular Monolith is an architectural style that combines the benefits of modularity with the simplicity of a monolithic application. It allows developers to build applications as a single unit while maintaining a clear separation of concerns through modules.

![img](https://www.milanjovanovic.tech/blogs/mnw_049/modular_monolith_diagram.png?imwidth=3840)
Reference:https://www.milanjovanovic.tech/blog/modular-monolith-communication-patterns

The Problem with Monoliths is that they become tightly coupled over time, making it difficult to maintain and scale the application.

A Modular Monolith addresses this issue by organizing the codebase into distinct modules, each responsible for a specific functionality.
Modules are loosely coupled and independent of each other, allowing for easier maintenance and scalability.

Modules cannot reference each other directly except through their public APIs.

There are two widely used communication patterns. Both have pros and cons and a set of tradeoffs that you need to understand.

## Synchronous Communication via Method Calls
The first and easiest communication pattern is simple method calls between modules. Method calls are synchronous and very fast because they're in memory.

Module A calls a method declared on the public API of Module B and waits until it receives a result.

Each module exposes a public API, which can be an interface in .NET.

The module will implement this interface internally and hide any implementation details. You can use the internal keyword to make the implementation inaccessible outside the module.

Modules depend on the interfaces at compile-time. At runtime, dependency injection will provide the respective implementation.

![img](https://www.milanjovanovic.tech/blogs/mnw_049/modular_monolith_sync_communication.png?imwidth=3840)
Reference: https://www.milanjovanovic.tech/blog/modular-monolith-communication-patterns

The benefits of this approach are:

    Speed of in-memory calls
    Easy to implement
    No indirection

But, the drawback of this approach is strong coupling.

Synchronous communication means that the modules will be tightly coupled. If one of the modules is unavailable, it will affect any dependent modules. You can introduce a retry mechanism, but this only goes so far.

## Asynchronous Communication via MessageBroker
The second communication pattern is asynchronous messaging between modules.

Module A sends a message to the message broker in a fire-and-forget fashion. Module B subscribes to relevant messages and handles them accordingly.

Modules don't need to know about each other, but they do need to know about the message contracts.

Message contracts are the public API of a module in this scenario.

![img](https://www.milanjovanovic.tech/blogs/mnw_049/modular_monolith_async_communication.png?imwidth=3840)
Reference: https://www.milanjovanovic.tech/blog/modular-monolith-communication-patterns

The benefits of this approach are:

    High availability
    Loose coupling

Asynchronous communication gives us loose coupling because modules communicate using messages. Module B doesn't need to be available for Module A to send a message.

The obvious drawback of this approach is increased complexity.

We're introducing a message broker to the system. This is another infrastructure component we have to manage. It's also a single point of failure. If the message broker fails, so does communication between the modules.

You can prevent message loss by storing messages in an Outbox before publishing them. We can always send the messages again from the database in case of a message broker failure.

In my opinion the big benefits of this approach are:
1. That it allows us to scale modules independently.
We can have multiple instances of Module B running, and they will all receive messages from Module A. 
2. If I communicate via messages to a module that is outsourced to a microservice. If the microservice is down, I can still send messages to the message broker and process them later when the microservice is back up and don't need to store them by my self.

## Conclusion
In conclusion, a Modular Monolith is an architectural style that combines the benefits of modularity with the simplicity of a monolithic application.

## References
For more information on Modular Monoliths, you can check out the following resources:
- [Milanjovanovic's Blog on Modular Monolith Communication Patterns](https://www.milanjovanovic.tech/blog/modular-monolith-communication-patterns)
