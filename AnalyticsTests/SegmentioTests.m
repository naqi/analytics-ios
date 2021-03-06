// SegmentioTests.m
// Copyright (c) 2014 Segment.io. All rights reserved.

#import <Kiwi/Kiwi.h>
#import "SEGAnalyticsUtils.h"
#import "SEGSegmentioIntegration.h"
#import "KWNotificationMatcher.h"

@interface SEGSegmentioIntegration (Private)
@property (nonatomic, readonly) NSMutableArray *queue;
@property (nonatomic, readonly) NSMutableDictionary *context;
@end

@interface SegmentioIntegrationDevelopment : SEGSegmentioIntegration

@end

@implementation SegmentioIntegrationDevelopment

- (id)initWithWriteKey:(NSString *)writeKey flushAt:(NSUInteger)flushAt {
    if (self = [super initWithWriteKey:writeKey flushAt:flushAt]) {
        self.apiURL = [NSURL URLWithString:@"http://localhost:7001/v1/import"];
    }
    return self;
}

@end

SPEC_BEGIN(SegmentioTests)

describe(@"Segment.io", ^{
    SEGSetShowDebugLogs(YES);

    __block SEGSegmentioIntegration *segmentio = nil;
    beforeAll(^{
        if ([[[NSProcessInfo processInfo] environment] objectForKey:@"CI"])
            segmentio = [[SEGSegmentioIntegration alloc] initWithWriteKey:@"testWriteKey" flushAt:2];
        else
            segmentio = [[SegmentioIntegrationDevelopment alloc] initWithWriteKey:@"suy5xxbtst" flushAt:2];
    });
    beforeEach(^{
        [segmentio reset];
    });
    
    it(@"Should have an anonymousId", ^{
        [segmentio.anonymousId shouldNotBeNil];
    });
    
    it(@"Should have a static context to spec", ^{
        NSDictionary *context = segmentio.context;
        
        [[context[@"library"][@"name"] should] equal:@"analytics-ios"];
        [[context[@"library"][@"version"] should] equal:SEGStringize(ANALYTICS_VERSION)];
        
        [[context[@"device"][@"manufacturer"] should] equal:@"Apple"];
        [context[@"device"][@"model"] shouldNotBeNil];
        
        [context[@"os"][@"name"] shouldNotBeNil];
        [context[@"os"][@"version"] shouldNotBeNil];
        
        [context[@"screen"][@"width"] shouldNotBeNil];
        [context[@"screen"][@"height"] shouldNotBeNil];
    });
    
    it(@"Should track", ^{
        NSString *eventName = @"Purchased an iPhone 6";
        [segmentio track:eventName properties:nil options:nil];

        [[expectFutureValue(@(segmentio.queue.count)) shouldEventually] equal:@1];

        NSDictionary *queuedTrack = segmentio.queue[0];
        [[queuedTrack[@"type"] should] equal:@"track"];
        [[queuedTrack[@"event"] should] equal:eventName];
        [queuedTrack[@"timestamp"] shouldNotBeNil];
        [queuedTrack[@"properties"] shouldBeNil];
        
        // send a second event, wait for 200 from servers
        [segmentio track:eventName properties:nil options:nil];
        
        [[SEGSegmentioDidSendRequestNotification shouldEventually] bePosted];
        [[SEGSegmentioRequestDidSucceedNotification shouldEventually] bePosted];
    });
    
    it(@"Should track with properties", ^{
        NSString *eventName = @"Purchased an iPad 5";
        NSDictionary *properties = @{@"Filter": @"Tilt-shift"};
        [segmentio track:eventName properties:properties options:nil];

        [[expectFutureValue(@(segmentio.queue.count)) shouldEventually] equal:@1];
        
        NSDictionary *queuedTrack = segmentio.queue[0];
        [[queuedTrack[@"type"] should] equal:@"track"];
        [[queuedTrack[@"event"] should] equal:eventName];
        [queuedTrack[@"timestamp"] shouldNotBeNil];
        
        [[queuedTrack[@"properties"] should] equal:properties];
        
        // send a second event, wait for 200 from servers
        [segmentio track:eventName properties:properties options:nil];
        [[SEGSegmentioDidSendRequestNotification shouldEventually] bePosted];
        [[SEGSegmentioRequestDidSucceedNotification shouldEventually] bePosted];
    });
    
    it(@"Should track with context", ^{
        NSString *eventName = @"Purchased an iPad 5";
        NSDictionary *properties = @{@"Filter": @"Tilt-shift"};
        NSDictionary *options = @{ @"integrations": @{ @"Salesforce": @"false", @"Mixpanel": @"true" } };
        [segmentio track:eventName properties:properties options:options];
        
        [[expectFutureValue(@(segmentio.queue.count)) shouldEventually] equal:@1];
        
        NSDictionary *queuedTrack = segmentio.queue[0];
        
        [[queuedTrack[@"type"] should] equal:@"track"];
        [[queuedTrack[@"event"] should] equal:eventName];
        [[queuedTrack[@"properties"] should] equal:properties];
        [queuedTrack[@"timestamp"] shouldNotBeNil];
        
        // test for integrations options object
        
        [queuedTrack[@"integrations"] shouldNotBeNil];
        [[queuedTrack[@"integrations"][@"Salesforce"] should] equal:@"false"];
        [[queuedTrack[@"integrations"][@"Mixpanel"] should] equal:@"true"];
        [queuedTrack[@"integrations"][@"KISSmetrics"] shouldBeNil];
        
        // send a second event, wait for 200 from servers
        [segmentio track:eventName properties:properties options:nil];
        [[SEGSegmentioDidSendRequestNotification shouldEventually] bePosted];
        [[SEGSegmentioRequestDidSucceedNotification shouldEventually] bePosted];
    });
    
    it(@"Should identify", ^{
        NSString *userId = @"smile@wrinkledhippo.com";
        [segmentio identify:userId traits:nil options:nil];
        
        [[expectFutureValue(@(segmentio.queue.count)) shouldEventually] equal:@1];
        
        NSDictionary *queuedTrack = segmentio.queue[0];
        [[queuedTrack[@"type"] should] equal:@"identify"];
        [[queuedTrack[@"userId"] should] equal:userId];
        [queuedTrack[@"anonymousId"] shouldNotBeNil];
        [queuedTrack[@"traits"] shouldBeNil];
        [queuedTrack[@"timestamp"] shouldNotBeNil];
        
        [segmentio identify:userId traits:nil options:nil];
        [[SEGSegmentioDidSendRequestNotification shouldEventually] bePosted];
        [[SEGSegmentioRequestDidSucceedNotification shouldEventually] bePosted];
    });
    
    it(@"Should identify with traits", ^{
        NSDictionary *traits = @{@"Filter": @"Tilt-shift"};
        [segmentio identify:nil traits:traits options:nil];
        
        [[expectFutureValue(@(segmentio.queue.count)) shouldEventually] equal:@1];
        
        NSDictionary *queuedTrack = segmentio.queue[0];
        [[queuedTrack[@"type"] should] equal:@"identify"];
        [queuedTrack[@"userId"] shouldBeNil];
        [queuedTrack[@"anonymousId"] shouldNotBeNil];
        [[queuedTrack[@"traits"] should] equal:traits];
        [queuedTrack[@"timestamp"] shouldNotBeNil];
        
        [segmentio identify:nil traits:traits options:nil];
        [[SEGSegmentioDidSendRequestNotification shouldEventually] bePosted];
        [[SEGSegmentioRequestDidSucceedNotification shouldEventually] bePosted];
    });
    
    it(@"Should identify with context", ^{
        NSDictionary *traits = @{@"Filter": @"Tilt-shift"};
        NSDictionary *options = @{ @"integrations": @{ @"Salesforce": @"true", @"Mixpanel": @"false" }};
        [segmentio identify:nil traits:traits options:options];
        
        [[expectFutureValue(@(segmentio.queue.count)) shouldEventually] equal:@1];
        
        NSDictionary *queuedAction = segmentio.queue[0];
        [[queuedAction[@"type"] should] equal:@"identify"];
        [queuedAction[@"userId"] shouldBeNil];
        [queuedAction[@"anonymousId"] shouldNotBeNil];
        [[queuedAction[@"traits"] should] equal:traits];
        [queuedAction[@"timestamp"] shouldNotBeNil];
        
        // test for integrations options object
        [queuedAction[@"integrations"] shouldNotBeNil];
        [[queuedAction[@"integrations"][@"Salesforce"] should] equal:@"true"];
        [[queuedAction[@"integrations"][@"Mixpanel"] should] equal:@"false"];
        [queuedAction[@"integrations"][@"KISSmetrics"] shouldBeNil];
        
        // send a second event, wait for 200 from servers
        [segmentio identify:nil traits:traits options:nil];
        [[SEGSegmentioDidSendRequestNotification shouldEventually] bePosted];
        [[SEGSegmentioRequestDidSucceedNotification shouldEventually] bePosted];
    });
    
    it(@"Should queue when not full", ^{
        [[segmentio.queue should] beEmpty];
        [segmentio.userId shouldBeNil];
        NSString *userId = @"smile@wrinkledhippo.com";
        [segmentio identify:userId traits:nil options:nil];
        [[segmentio.userId shouldEventually] beNonNil];
        [[segmentio.queue shouldEventually] have:1];
        [[SEGSegmentioDidSendRequestNotification shouldNotEventually] bePosted];
    });
    
    it(@"Should flush when full", ^{
        NSString *eventName = @"Purchased an iPad 5";
        NSDictionary *properties = @{@"Filter": @"Tilt-shift"};
        [[segmentio.queue shouldEventually] have:2];
        [[SEGSegmentioDidSendRequestNotification shouldEventually] bePosted];
        [[SEGSegmentioRequestDidSucceedNotification shouldEventually] bePosted];
        [segmentio track:eventName properties:properties options:nil];
        [segmentio track:eventName properties:properties options:nil];
    });
    
    it(@"Should reset", ^{
        NSString *eventName = @"Purchased an iPad 5";
        NSDictionary *properties = @{@"Filter": @"Tilt-shift", @"category": @"Mobile", @"revenue": @"70.0", @"value": @"50.0", @"label": @"gooooga"};
        NSDictionary *options = @{ @"integrations": @{ @"Salesforce": @YES, @"HubSpot": @NO } };
        NSString *anonymousId = segmentio.anonymousId;
        
        [segmentio track:eventName properties:properties options:options];
        [[expectFutureValue(@(segmentio.queue.count)) shouldEventually] equal:@1];
        [segmentio reset];
        
        [[segmentio.queue should] beEmpty];
        [[segmentio.anonymousId shouldNot] equal:anonymousId];
        [[SEGSegmentioDidSendRequestNotification shouldNotEventually] bePosted];        
    });
});

SPEC_END