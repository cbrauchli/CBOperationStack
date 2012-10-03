CBOperationStack
================

A LIFO (last in, first out) Objective-C implementation of [Apple's NSOperationQueue](https://developer.apple.com/library/mac/#documentation/Cocoa/Reference/NSOperationQueue_class/Reference/Reference.html). 


Interface
=========

`CBOperationStack` has the same interface as [`NSOperationQueue`](https://developer.apple.com/library/mac/#documentation/Cocoa/Reference/NSOperationQueue_class/Reference/Reference.html) with the difference that operations are (roughly) run in a last in, first out order as opposed to `NSOperationQueue`'s first in, first out order. 

The other difference from `NSOperationQueue` is the addition of one method:

    - (void)addOperationAtBottomOfStack:(NSOperation *)op;

which effectively allows you to use `CBOperationStack` as a queue. 

`CBOperationStack` does not implement either the `+ (id)currentQueue` or `+ (id)mainQueue` methods yet.
