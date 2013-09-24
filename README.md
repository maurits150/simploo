SIMPLOO - The simple lua object-oriented programming library!
=====

#### Introduction

SIMPLOO is a library designed to integrate the object-oriented programming concept into Lua.

#### Features

** Quick Feature Overview **

* public/protected/private access modifiers
* abstract/final classes and class members
* multiple inheritance
* constructors/finalizers that are called on garbage collection (in both Lua 5.1 and 5.2)
* common OOP functions such as is\_a() and instance\_of()
* iteration-less member access due to build in registry system.
* metamethod support

#### Additional Notes

* This library uses the following globals: SIMPLOO, null, class, extends, options, public, protected, private, static, abstract, meta, final
* There are no guarantees that this library behaves exactly like other object oriented programming languages, albeit it comes pretty close.

#### Requirements

This library is being developed and tested on LuaJIT 2.1.0 (Lua 5.1) and Lua 5.2.
For the best performance I absolutely recommend using a LuaJIT environment.

#### Installation

Simply include the simploo.lua file in the beginning of your code and you're ready to go!

#### Usage

Please refer to the wiki!

https://github.com/maurits150/simploo/wiki

#### Feedback

Any feedback is appreciated.