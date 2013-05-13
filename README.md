SIMPLOO - The simple lua object-oriented programming library!
=====

#### Introduction

SIMPLOO is a library designed to integrate object-oriented programming concepts into Lua.

This library takes advantage of Lua's flexibility to provide you with a very simple and straightforward syntax.
#### Features

**Classes**

* Support for public/protected/private access modifiers.
* Single inheritance from other classes (you can only inherit one parent class, but you can create an unlimited chain of classes)
* Constructors that can be overridden on a per-instance basis. (or disabled entirely by setting it private)
* Common OOP functions such as is\_a() and instance\_of().
* The ability to implement multiple interfaces, see below:
* Separation between classes and instances.
 * Each instance has an actual instance of it's super classes too.
 * Support for the 'super' keyword to reach the members of a super class.
 * Any requests to non-existant class members will traverse up the derivation tree.
 * The aforementioned operates at O(1) speed due to a build-in member registry. There's no iterating taking place!


**Interfaces**

* Define members and their corresponding access modifiers.
* Single inheritance from other interfaces.
* Interfaces are checked against the implementing class in their entire, including:
 * member name
 * member access modifier
 * member lua type
 * in case that the member is a function: member arguments

#### Installation

Simple include the simploo.lua file in your code.
