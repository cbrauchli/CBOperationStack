//
//  CBOperationStack.h
//
//  Created by Chris Brauchli on 10/01/12.
//  Copyright (c) 2012 Chris Brauchli. All rights reserved.
//
//  Some ideas and code copied from Cocotron: http://code.google.com/p/cocotron/
//

#import <Foundation/Foundation.h>

@interface CBOperationStack : NSObject

@property (nonatomic, copy)              NSString   * name;
@property (readonly)                     NSArray    * operations;
@property (readonly)                     NSUInteger   operationCount;
@property (nonatomic, assign)            NSInteger    maxConcurrentOperationCount;
@property (assign, getter = isSuspended) BOOL         suspended;

- (void)addOperation:(NSOperation *)op;
- (void)addOperationWithBlock:(void (^)(void))block;
- (void)addOperations:(NSArray *)ops waitUntilFinished:(BOOL)wait;
- (void)addOperationWithBlock:(void (^)(void))block;
- (void)addOperationAtBottomOfStack:(NSOperation *)op;

- (void)cancelAllOperations;

- (void)waitUntilAllOperationsAreFinished;

// TODO: implement these
//+ (id)currentQueue;
//+ (id)mainQueue;

@end
