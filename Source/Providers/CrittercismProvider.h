// CrittercismProvider.h
// Copyright 2013 Segment.io

#import <Foundation/Foundation.h>
#import "Provider.h"


@interface CrittercismProvider : Provider

@property(nonatomic, strong) NSString *name;
@property(nonatomic, assign) BOOL enabled;
@property(nonatomic, assign) BOOL valid;
@property(nonatomic, assign) BOOL initialized;
@property(nonatomic, strong) NSDictionary *settings;

+ (instancetype)withNothing;
- (id)initWithNothing;

@end