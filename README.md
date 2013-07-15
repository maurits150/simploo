SIMPLOO - The simple lua object-oriented programming library!
=====

##### Warning: This library is still a work in progress. Do not expect it to be bug free.

#### Introduction

SIMPLOO is a library designed to integrate object-oriented programming concepts into Lua.

This library takes advantage of Lua's flexibility to provide you with a very simple and straightforward syntax.

#### Features

**Classes**

* Supports public/protected/private access modifiers.
* Supports static member variables.
* Supports final member variables and classes.
* Single inheritance from other classes (you can only inherit one class)
* Constructors that can be overridden on a per-class basis. (or disabled entirely by setting it private)
* Common OOP functions such as is\_a() and instance\_of().
* The ability to implement one or more interfaces.
* Separation between classes and instances.
    * Each instance with parent classes, has an actual instance of it's parents too.
    * Support for the 'super' keyword to reach the members of a super class.
    * Any requests to non-existant class members will traverse up the derivation tree.
    * The aforementioned operates at O(1) speed due to a build-in member registry. There's no iteration taking place, even when you chain 1000 classes together!

**Interfaces**

* Define members and their corresponding modifiers.
* Single inheritance from other interfaces.
* The following conditions have to match up between a class and an interface in order to succeed implementation: (for each member)
    * member name
    * member value type (number, string, boolean, function etc)
        * when the member value type is a function: checks if the function arguments match up
    * member access modifier
    * member static modifier
    * member final modifier


#### Additional Notes

* This library uses the following globals: class, interface, extends, implements, options, public, private, protected, static, final. Make sure these globals aren't already used in your code.
* The protected access modifier uses the debug.getinfo function to figure out if member lookups came from outside the class hierarchy. This function isn't extremely fast, and thus lookups to protected members will significantly slower. Use with caution!

#### Requirements

This library was build and tested on LuaJIT 2.0.1.

#### Installation

Simply include the simploo.lua file in your code somewhere and you're ready to go!

#### Examples & Usage

Please refer to the wiki!

https://github.com/maurits150/simploo/wiki