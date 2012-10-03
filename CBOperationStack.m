//
//  CBOperationStack.m
//
//  Created by Chris Brauchli on 10/01/12.
//  Copyright (c) 2012 Chris Brauchli. All rights reserved.
//
//  Some ideas and code copied from Cocotron: http://code.google.com/p/cocotron/
//

#import "CBOperationStack.h"

static const NSUInteger NSOperationQueuePriorityCount = 5;

@interface NSMutableArray (CBStackOperations)
- (id)CBpopObject;
@end
@implementation NSMutableArray (CBStackOperations)
- (id)CBpopObject
{
  id obj = [self lastObject];
  if (obj) {
    [self removeLastObject];
  }
  return obj;
}
@end


inline static void ClearQueues(NSArray *queues)
{
  for (NSMutableArray *queue in queues) {
    [queue removeAllObjects];
  }
}


@implementation CBOperationStack {
	NSCondition *workAvailable;
	NSCondition *suspendedCondition;
	NSCondition *allWorkDone;
	
	NSArray *queues;
  NSMutableArray *_threads;
}

@synthesize name;
@synthesize maxConcurrentOperationCount;
@dynamic operationCount;
@dynamic operations;
@synthesize suspended = isSuspended;


- (id)init
{
  self = [super init];

  if (self) {
    workAvailable = [[NSCondition alloc] init];
    suspendedCondition = [[NSCondition alloc] init];
    allWorkDone = [[NSCondition alloc] init];
    isSuspended = NO;

    maxConcurrentOperationCount = 1;

    NSMutableArray *queuesTemp = [NSMutableArray arrayWithCapacity:NSOperationQueuePriorityCount];
    for (NSUInteger i=0; i < NSOperationQueuePriorityCount; i++) {
      NSMutableArray *queue = [NSMutableArray array];
      [queuesTemp addObject:queue];
    }
    queues = queuesTemp;

    NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(_workThread) object:nil];
    thread.name = @"Thread 0";
    _threads = [NSMutableArray arrayWithObject:thread];
    [thread start];
  }
  
	return self;
}

#pragma mark - Suspension
- (void)resume
{
  [suspendedCondition lock];
	if (isSuspended) {
		isSuspended = NO;
		[suspendedCondition broadcast];
  }
	[suspendedCondition unlock];
}

- (void)suspend
{
	[suspendedCondition lock];
	isSuspended = YES;
	[suspendedCondition unlock];
}


- (void)stop
{
  for (NSThread *thread in _threads) {
    [thread cancel];
  }
	[self resume];
  [workAvailable lock];
	[workAvailable broadcast];
  [workAvailable unlock];
}


- (void)dealloc
{
	[self stop];
	
	ClearQueues(queues);
}

inline static NSUInteger getPriority(NSOperation *op)
{
  NSUInteger priority;
  switch ([op queuePriority]) {
    case NSOperationQueuePriorityVeryLow:
      priority = 4;
      break;
    case NSOperationQueuePriorityLow:
      priority = 3;
      break;
    case NSOperationQueuePriorityNormal:
      priority = 2;
      break;
    case NSOperationQueuePriorityHigh:
      priority = 1;
      break;
    case NSOperationQueuePriorityVeryHigh:
      priority = 0;
      break;
    default:
      priority = 2;
      break;
  }
  return priority;
}

- (void)addOperation:(NSOperation *)op
{
	NSUInteger priority = getPriority(op);
  [workAvailable lock];
  @synchronized(self) {
    [[queues objectAtIndex:priority] addObject:op];
  }
	[workAvailable signal];
  [workAvailable unlock];
}

- (void)addOperationAtBottomOfStack:(NSOperation *)op
{
  NSUInteger priority = getPriority(op);
  [workAvailable lock];
  @synchronized(self) {
    [[queues objectAtIndex:priority] insertObject:op atIndex:0];
  }
  [workAvailable signal];
  [workAvailable unlock];
}

- (void)addOperationWithBlock:(void (^)(void))block
{
  NSOperation *op = [NSBlockOperation blockOperationWithBlock:block];
  [self addOperation:op];
}

- (void)addOperations:(NSArray *)ops waitUntilFinished:(BOOL)wait
{
  for (NSOperation *op in ops)
    [self addOperation:op];
  
  if (wait)
    [self waitUntilAllOperationsAreFinished];
}

- (void)cancelAllOperations
{
	[[self operations] makeObjectsPerformSelector:@selector(cancel)];
}

- (void)setMaxConcurrentOperationCount:(NSInteger)count
{
  if (count < 0 || count == NSOperationQueueDefaultMaxConcurrentOperationCount) maxConcurrentOperationCount = 1;
  else maxConcurrentOperationCount = count;
  
  @synchronized(self) {
    NSInteger difference = maxConcurrentOperationCount - _threads.count;
    
    while (difference > 0) {
      NSThread *thread = [[NSThread alloc] initWithTarget:self selector:@selector(_workThread) object:nil];
      thread.name = [NSString stringWithFormat:@"Thread %d", _threads.count];
      [_threads addObject:thread];
      [thread start];
      difference--;
    }
    
    while (difference < 0) {
      NSThread *thread = [_threads CBpopObject];
      [thread cancel];
      difference++;
    }
  }
  [workAvailable lock];
  [workAvailable broadcast];
  [workAvailable unlock];
}

- (NSArray *)operations
{
	NSMutableArray *operations = [NSMutableArray arrayWithCapacity:operationCount];
	@synchronized(self) {
    for (NSMutableArray *queue in queues) {
      [operations addObjectsFromArray:queue];
		}
	}
	return operations;
}

- (NSUInteger)operationCount
{
  NSUInteger count = 0;
  @synchronized(self) {
    for (NSMutableArray *queue in queues)
      count += queue.count;
  }
  return count;
}

- (BOOL)isSuspended
{
	[suspendedCondition lock];
	BOOL result = isSuspended;
	[suspendedCondition unlock];
	return result;
}

-(void)setSuspended:(BOOL)suspend
{
	if (suspend)
    [self suspend];
	else
    [self resume];
}

-(BOOL)hasMoreWork
{
  for (NSMutableArray *queue in queues)
    if (queue.count > 0)
      return YES;
  
	return NO;
}

-(void)waitUntilAllOperationsAreFinished
{
  BOOL isWorking;
  
  [workAvailable lock];
  isWorking = [self hasMoreWork];
  [workAvailable unlock];
  
  if(isWorking) {
    [allWorkDone lock];
    [allWorkDone wait];
    [allWorkDone unlock];
  }
}

// pop an operation from the given list and run it
// if the list is empty, steal the source list into the given list and run an operation from it
// if both are empty, do nothing
// returns YES if an operation was executed, NO otherwise
// - (BOOL)_runOperationFromList: (NSAtomicListRef *)listPtr sourceList: (NSAtomicListRef *)sourceListPtr
//static BOOL RunOperationFromLists( NSAtomicListRef *listPtr, NSAtomicListRef *sourceListPtr, CBOperationStack *opstack )
inline static BOOL _runOperationFromLists(NSMutableArray *queue, NSMutableArray *sourceQueue, CBOperationStack *opstack)
{
	NSOperation *op = nil;
	@synchronized(opstack) {
    op = [queue CBpopObject];
		if(!op) {
			op = [sourceQueue CBpopObject];
		}
	}
	if (op) {
		if ([op isReady]) {
			[op start];
		} else {
			@synchronized(opstack) {
        [sourceQueue addObject:op];
			}
		}
	}
	
	return op != nil;
}

- (void)_workThread
{
	NSThread *thread = [NSThread currentThread];
	
  NSMutableArray *myQueues = [NSMutableArray arrayWithCapacity:NSOperationQueuePriorityCount];
  for (NSUInteger i=0; i<NSOperationQueuePriorityCount; i++) {
    NSMutableArray *queue = [NSMutableArray array];
    [myQueues addObject:queue];
  }
	
	BOOL didRun = NO;
	while(![thread isCancelled])
	{
		[suspendedCondition lock];
    
		while (isSuspended)
      [suspendedCondition wait];
    
		[suspendedCondition unlock];
		
		if(!didRun) {
			[workAvailable lock];
      
      if(![self hasMoreWork]){
        [allWorkDone lock];
        [allWorkDone broadcast];
        [allWorkDone unlock];
      }
      
			while (![self hasMoreWork] && ![thread isCancelled])
        [workAvailable wait];
      
			[workAvailable unlock];
		}
		
		for (NSUInteger i=0; i < NSOperationQueuePriorityCount; i++) {
      didRun = _runOperationFromLists([myQueues objectAtIndex:i], [queues objectAtIndex:i], self);
			if (didRun)
        break;
		}
  }
	
	// This thread got cancelled, so insert all of its operations back into the main queue.
	// The thread pool could have been reduced and then other threads should do this thread's work.
	@synchronized(self) {
		for (NSUInteger i=0; i < NSOperationQueuePriorityCount; i++) {
			id op = nil;
      NSMutableArray *myQueue = [myQueues objectAtIndex:i];
      NSMutableArray *queue = [queues objectAtIndex:i];
			while ((op = [myQueue CBpopObject])) {
        [queue addObject:op];
			}
		}
		ClearQueues(myQueues);
	}
}


@end
