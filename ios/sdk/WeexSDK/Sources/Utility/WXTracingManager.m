/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

#import "WXTracingManager.h"
#import "WXComponentFactory.h"
#import "WXModuleFactory.h"
#import "WXSDKManager.h"
#import <WeexSDK/WXComponentFactory.h>
#import <WeexSDK/WXModuleFactory.h>
#import <WeexSDK/WXHandlerFactory.h>


@implementation WXTracing

@end

@implementation WXTracingTask

@end

@interface WXTracingManager()

@property (nonatomic) BOOL isTracing;
@property (nonatomic, strong) NSMutableDictionary *tracingTasks;  // every instance have a task
@property (nonatomic, copy) NSString *currentInstanceId;  // every instance have a task

@end

@implementation WXTracingManager


+ (instancetype) sharedInstance{
    
    static WXTracingManager *instance = nil;
    static dispatch_once_t once;
    
    dispatch_once(&once, ^{
        instance = [[WXTracingManager alloc] initPrivate];
    });
    
    return instance;
}

- (instancetype) initPrivate{
    self = [super init];
    if(self){
        self.isTracing = YES;
    }
    
    return self;
}

+(void)switchTracing:(BOOL )isTracing
{
    [WXTracingManager sharedInstance].isTracing = isTracing;
}

+(BOOL)isTracing
{
#if DEBUG
    return YES;
    return [WXTracingManager sharedInstance].isTracing;
#else
    return NO;
#endif
}

+(void)startTracing:(WXTracing *)tracing
{
    if([self isTracing]){
        if(![WXTracingManager sharedInstance].tracingTasks){
            [WXTracingManager sharedInstance].tracingTasks = [NSMutableDictionary new];
        }
        if(![[WXTracingManager sharedInstance].tracingTasks objectForKey:tracing.iid]){
            WXTracingTask *task = [WXTracingTask new];
            task.iid = tracing.iid;
            [[WXTracingManager sharedInstance].tracingTasks setObject:task forKey:tracing.iid];
        }
        WXTracingTask *task = [[WXTracingManager sharedInstance].tracingTasks objectForKey:tracing.iid];
        if(!task.tracings){
            task.tracings = [NSMutableArray new];
        }
        NSTimeInterval time=[[NSDate date] timeIntervalSince1970]*1000;
        tracing.ts = time;
        if(![WXTracingEnd isEqualToString:tracing.ph]){ // end is should not update
            tracing.traceId = ++task.counter;
        }
        if([WXTNetworkHanding isEqualToString:tracing.name] && [WXTracingBegin isEqualToString:tracing.ph]){
            task.tag = WXTNetworkHanding;
        }
        NSTimeInterval ts = [[NSDate date] timeIntervalSince1970]*1000;
        tracing.ts = ts ;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self updateTracings:task tracing:tracing];
        });
    }
}

+(void)setBundleJSType:(NSString *)jsBundleString instanceId:(NSString *)iid
{
    if([self isTracing] && iid.length >0){
        WXTracingTask *task = [[WXTracingManager sharedInstance].tracingTasks objectForKey:iid];
        if(jsBundleString.length >0){
            NSRange range = [jsBundleString rangeOfString:@"}"];
            if (range.location != NSNotFound) {
                NSString *searchStr =  [jsBundleString substringToIndex:range.location+range.length];
                if ([searchStr rangeOfString:@"Vue"].location != NSNotFound){
                    task.bundleJSType = @"Vue";
                }else if([searchStr rangeOfString:@"Rax"].location != NSNotFound){
                    task.bundleJSType = @"Rax";
                }
            }
        }
    }
}

+(void)startTracing:(NSString *)iid ref:(NSString*)ref parentRef:(NSString*)parentRef className:(NSString *)className name:(NSString *)name ph:(NSString *)ph fName:(NSString *)fName parentId:(NSString *)parentId
{
    if([self isTracing]){
        WXTracing *tracing = [WXTracing new];
        if(ref.length>0){
            tracing.ref = ref;
        }
        if(parentRef.length>0){
            tracing.parentRef = parentRef;
        }
        if(className.length>0){
            tracing.className = className;
        }
        if(name.length>0){
            tracing.name = name;
        }
        if(fName.length>0){
            tracing.fName = fName;
        }
        if(ph.length>0){
            tracing.ph = ph;
        }
        if(iid.length>0){
            tracing.iid = iid;
        }
        if(parentId.length>0){
            tracing.parentId = parentId;
        }
        [self startTracing:tracing];
    }
}

+(WXTracing *)copyTracing:(WXTracing *)tracing
{
    WXTracing *newTracing = [WXTracing new];
    if(tracing.ref.length>0){
        newTracing.ref = tracing.ref;
    }
    if(tracing.parentRef.length>0){
        newTracing.parentRef = tracing.parentRef;
    }
    if(tracing.className.length>0){
        newTracing.className = tracing.className;
    }
    if(tracing.name.length>0){
        newTracing.name = tracing.name;
    }
    if(tracing.fName.length>0){
        newTracing.fName = tracing.fName;
    }
    if(tracing.ph.length>0){
        newTracing.ph = tracing.ph;
    }
    if(tracing.iid.length>0){
        newTracing.iid = tracing.iid;
    }
    if(tracing.parentId.length>0){
        newTracing.parentId = tracing.parentId;
    }
    if(tracing.traceId>0){
        newTracing.traceId = tracing.traceId;
    }
    if(tracing.ts>0){
        newTracing.ts = tracing.ts;
    }
    return newTracing;
}

+(NSString *)getclassName:(WXTracing *)tracing
{
    NSString *className = @"";
    if(tracing.ref.length>0 && tracing.name.length >0){
        Class cls = [WXComponentFactory classWithComponentName:tracing.name];
        className = NSStringFromClass(cls);
    }else if(tracing.name.length > 0){
        Class cls = [WXModuleFactory classWithModuleName:tracing.name];
        if(cls){
            className = NSStringFromClass(cls);
        }
    }
    return  className;
}

+(void)updateTracings:(WXTracingTask *)task tracing:(WXTracing *)tracing
{
    if(![WXTJSCall isEqualToString:tracing.name]){
        tracing.className = [self getclassName:tracing];
    }
    if([WXTNetworkHanding isEqualToString:task.tag]){
        if([WXTDataHanding isEqualToString:tracing.name]){
            NSMutableArray *tracings = task.tracings;
            [tracings enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(WXTracing *bTracing, NSUInteger idx, BOOL *stop) {
                if(([WXTNetworkHanding isEqualToString:bTracing.name] || [bTracing.ref isEqualToString:tracing.ref])&&[WXTracingBegin isEqualToString:bTracing.ph]){
                    WXTracing *newTracing = [self copyTracing:bTracing];
                    newTracing.iid = tracing.iid;
                    newTracing.ph = WXTracingEnd;
                    newTracing.ts = tracing.ts ;
                    newTracing.duration = newTracing.ts - bTracing.ts ;
                    bTracing.duration = newTracing.duration;
                    [task.tracings addObject:newTracing];
                    NSLog(@"jerry0 %f,%f",bTracing.ts,bTracing.duration);
                    *stop = YES;
                }
            }];
            task.tag = WXTDataHanding;
        }
    }
    
    if([WXTDataHanding isEqualToString:task.tag]){
        if([WXTJSCall isEqualToString:tracing.name]){
            NSMutableArray *tracings = task.tracings;
            [tracings enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(WXTracing *bTracing, NSUInteger idx, BOOL *stop) {
                if(([WXTDataHanding isEqualToString:bTracing.name] || [bTracing.ref isEqualToString:tracing.ref])&&[WXTracingBegin isEqualToString:bTracing.ph]){
                    WXTracing *newTracing = [self copyTracing:bTracing];
                    newTracing.iid = tracing.iid;
                    newTracing.ph = WXTracingEnd;
                    newTracing.ts = tracing.ts ;
                    newTracing.duration = newTracing.ts - bTracing.ts ;
                    bTracing.duration = newTracing.duration;
                    [task.tracings addObject:newTracing];
                    NSLog(@"jerry1 %f,%f",bTracing.ts,bTracing.duration);
                    *stop = YES;
                }
            }];
            task.tag = WXTRender;
        }
    }
    if([WXTracingEnd isEqualToString:tracing.ph]){  // deal end
        NSMutableArray *tracings = task.tracings;
        [tracings enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(WXTracing *bTracing, NSUInteger idx, BOOL *stop) {
            if(tracing.ref.length > 0 && bTracing.ref.length>0){
                if(![tracing.ref isEqualToString:bTracing.ref]){
                    return ;
                }
            }
            
            if([bTracing.fName isEqualToString:tracing.fName] &&[WXTracingBegin isEqualToString:bTracing.ph]){
                tracing.iid = bTracing.iid;
                if(bTracing.ref.length > 0){
                    tracing.ref = bTracing.ref;
                }
                tracing.duration = tracing.ts - bTracing.ts ;
                tracing.traceId = bTracing.traceId;
                bTracing.duration = tracing.duration;
                NSLog(@"jerry2 %f,%f",bTracing.ts,bTracing.duration);
                *stop = YES;
            }
        }];
    }
    [task.tracings addObject:tracing];
}

+(WXTracingTask *)getTracingData
{
    NSArray *instanceIds = [[WXSDKManager bridgeMgr] getInstanceIdStack];
    WXTracingTask *task = [[WXTracingManager sharedInstance].tracingTasks objectForKey:[instanceIds firstObject]];
    return task;
}

+(void)getTracingData:(NSString *)instanceId{
    WXTracingTask *task = [[WXTracingManager sharedInstance].tracingTasks objectForKey:instanceId];
    NSArray *tracings = [task.tracings copy];
    for (WXTracing *tracing in tracings) {
        if(![WXTracingBegin isEqualToString:tracing.ph]){
//            NSLog(@"%lld %@  %@  %@  %f %f %@  %@",tracing.traceId,tracing.fName,tracing.name,tracing.className,tracing.ts,tracing.duration,tracing.ref,tracing.parentRef);
        }
    }
}

+(NSDictionary *)getTacingApi
{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    NSMutableArray *componetArray = [NSMutableArray new];
    NSMutableArray *moduleArray = [NSMutableArray new];
    NSMutableArray *handleArray = [NSMutableArray new];
    NSDictionary *componentConfigs = [WXComponentFactory componentConfigs];
    void (^componentBlock)(id, id, BOOL *) = ^(id mKey, id mObj, BOOL * mStop) {
        NSMutableDictionary *componentConfig = [mObj mutableCopy];
        NSDictionary *cDict = [WXComponentFactory componentMethodMapsWithName:componentConfig[@"name"]];
        if(cDict && [cDict count]>0 && [cDict[@"methods"] count]>0){
            [componentConfig setObject:cDict[@"methods"] forKey:@"methods"];
        }
        [componetArray addObject:componentConfig];
    };
    [componentConfigs enumerateKeysAndObjectsUsingBlock:componentBlock];
    if(componetArray && [componetArray count]>0){
        [dict setObject:componetArray forKey:@"componet"];
    }
    NSDictionary *moduleConfigs = [WXModuleFactory moduleConfigs];
    void (^moduleBlock)(id, id, BOOL *) = ^(id mKey, id mObj, BOOL * mStop) {
        NSDictionary *mDict = [WXModuleFactory moduleMethodMapsWithName:mKey];
        NSMutableDictionary *subDict = [NSMutableDictionary new];
        [subDict setObject:mKey forKey:@"name"];
        [subDict setObject:mObj forKey:@"class"];
        if([mDict objectForKey:mKey]){
            [subDict setObject:[mDict objectForKey:mKey] forKey:@"methods"];
        }
        [moduleArray addObject:subDict];
    };
    [moduleConfigs enumerateKeysAndObjectsUsingBlock:moduleBlock];
    if(moduleArray && [moduleArray count]>0){
        [dict setObject:moduleArray forKey:@"module"];
    }
    
    
    NSDictionary *handleConfigs = [[WXHandlerFactory handlerConfigs] mutableCopy];
    void (^handleBlock)(id, id, BOOL *) = ^(id mKey, id mObj, BOOL * mStop) {
        NSMutableDictionary *subDict = [NSMutableDictionary new];
        [subDict setObject:mKey forKey:@"class"];
        [subDict setObject:NSStringFromClass([mObj class]) forKey:@"name"];
        [handleArray addObject:subDict];
    };
    [handleConfigs enumerateKeysAndObjectsUsingBlock:handleBlock];
    if(handleArray && [handleArray count]>0){
        [dict setObject:handleArray forKey:@"handle"];
    }
    
    return dict;
}

@end
