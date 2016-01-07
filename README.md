# SIMPLOO `2.0` - Simple Lua Object Orientation
---

### Status
This version is still a work in progress but is expected to be fully backwards compatible with `1.0`.

Notably, this version has not been broadly tested yet so unexpected errors may occur. Due to its numerous improvements it's still highly recommended to use this version instead of the previous one however.

### Introduction
SIMPLOO is a library for the Lua programming language. Its goal is to simplify class based object-oriented programming inside Lua. 

Lua is generally considered to be prototype-based language, which means that it's possible to define individual objects with their own states and behaviors. However, more advanced concepts such as inheritance and encapsulations are harder to achieve because Lua lacks the syntax to formally express these concepts.

The general workaround for these limitations is to modify the behavior of the object itself to include these concepts instead of relying on the language. Unfortunately this is often challenging and time consuming, especially when you have many different types of objects and behaviors.

This library is designed to help with this process by using the freedom of Lua to emulate the same class-based programming syntax that's so often seen in other languages. After you've provided a class definition you can easily derive new objects from it, and SIMPLOO will handle everything that's required to make your objects behave appropriately.

### Changes compared to `1.0`
* The library has been rewritten in order to be more maintainable.
* New syntax features have been added to make classes even more organisable.
* Performance has been increased by lowering internal overhead.

### Requirements
* This library has been developed and tested on Lua 5.1, Lua 5.2 and LuaJIT.
* The availability of the debug library (specifically debug.getupvalue and debug.setupvalue) is only required for Lua 5.2, in order to support the 'using' keyword. 

### Expectations
This library attempts to emulate classes as closely as possible and it's pretty fast doing so. Regardless, its code is still interpreted in real-time and instantiating a new instance still takes a little bit of time to complete- most of it spend on deep copying data.

It's best to use this library to keep track of longer lived objects- for example entities in a game world. It's not going to perform in an environment where you require thousands of new objects every seconds- for example to store data from network packets. Also, instantiation time scales linearly with the amount of members that a class has. This includes members that are present in parent classes.

We've benchmarked SIMPLOO on an i7 920 processor clocked to 4 GHz. In this benchmark we've defined a class with 5 public functions, 5 public variables, 5 private functions and 5 private variables and measured how long it took to create 10k instances. Keep in mind that Lua is single threaded.

* 10k instances in Lua 5.1: ~0.72 seconds
* 10k instances in Lua 5.2: ~0.82 seconds
* 10k instances in LuaJIT: ~0.26 seconds
