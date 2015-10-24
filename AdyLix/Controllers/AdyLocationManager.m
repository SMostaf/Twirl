//
//  LocationManager.h
//
//  Copyright (c) 2014-2015 Adyit Inc.
//
//  Permission is hereby granted, free of charge, to any person obtaining
//  a copy of this software and associated documentation files (the
//  "Software"), to deal in the Software without restriction, including
//  without limitation the rights to use, copy, modify, merge, publish,
//  distribute, sublicense, and/or sell copies of the Software, and to
//  permit persons to whom the Software is furnished to do so, subject to
//  the following conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
//  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
//  LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
//  OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
//  WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

//
//  AdyLocationManager.m
//  AdyLix
//
//  Created by Sahar Mostafa on 10/23/15.
//  Copyright © 2015 Sahar Mostafa. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "AdyLocationManager.h"
#import "AdyLocationManager+Internal.h"
#import "AdyLocationManager.h"
#import "AdyLocationRequest.h"

#if ADY_ENABLE_LOGGING
#   define ADYLMLog(...)          NSLog(@"ADYLocationManager: %@", [NSString stringWithFormat:__VA_ARGS__]);
#else
#   define ADYLMLog(...)
#endif /* Ady_ENABLE_LOGGING */


@interface AdyLocationManager () <CLLocationManagerDelegate, AdyLocationRequestDelegate>

/** The instance of CLLocationManager encapsulated by this class. */
@property (nonatomic, strong) CLLocationManager *locationManager;
/** The most recent current location, or nil if the current location is unknown, invalid, or stale. */
@property (nonatomic, strong) CLLocation *currentLocation;
/** Whether or not the CLLocationManager is currently monitoring significant location changes. */
@property (nonatomic, assign) BOOL isMonitoringSignificantLocationChanges;
/** Whether or not the CLLocationManager is currently sending location updates. */
@property (nonatomic, assign) BOOL isUpdatingLocation;
/** Whether an error occurred during the last location update. */
@property (nonatomic, assign) BOOL updateFailed;

// An array of active location requests in the form:
// @[ INTULocationRequest *locationRequest1, INTULocationRequest *locationRequest2, ... ]
@property (nonatomic, strong) __Ady_GENERICS(NSArray, AdyLocationRequest *) *locationRequests;


@end


@implementation AdyLocationManager

static id _sharedInstance;

/**
 Returns the current state of location services for this app, based on the system settings and user authorization status.
 */
+ (AdyLocationServicesState)locationServicesState
{
    if ([CLLocationManager locationServicesEnabled] == NO) {
        return AdyLocationServicesStateDisabled;
    }
    else if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined) {
        return AdyLocationServicesStateNotDetermined;
    }
    else if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusDenied) {
        return AdyLocationServicesStateDenied;
    }
    else if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusRestricted) {
        return AdyLocationServicesStateRestricted;
    }
    
    return AdyLocationServicesStateAvailable;
}

/**
 Returns the singleton instance of this class.
 */
+ (instancetype)sharedInstance
{
    static dispatch_once_t _onceToken;
    dispatch_once(&_onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

- (instancetype)init
{
    NSAssert(_sharedInstance == nil, @"Only one instance of AdyLocationManager should be created. Use +[AdyLocationManager sharedInstance] instead.");
    self = [super init];
    if (self) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        
#ifdef __IPHONE_8_4
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_8_4
        /* iOS 9 requires setting allowsBackgroundLocationUpdates to YES in order to receive background location updates.
         We only set it to YES if the location background mode is enabled for this app, as the documentation suggests it is a
         fatal programmer error otherwise. */
        NSArray *backgroundModes = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIBackgroundModes"];
        if ([backgroundModes containsObject:@"location"]) {
            if ([_locationManager respondsToSelector:@selector(setAllowsBackgroundLocationUpdates:)]) {
                [_locationManager setAllowsBackgroundLocationUpdates:YES];
            }
        }
#endif /* __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_8_4 */
#endif /* __IPHONE_8_4 */
        
        _locationRequests = @[];
    }
    return self;
}

/**
 Asynchronously requests the current location of the device using location services.
 
 @param desiredAccuracy The accuracy level desired (refers to the accuracy and recency of the location).
 @param timeout         The maximum amount of time (in seconds) to wait for a location with the desired accuracy before completing.
 If this value is 0.0, no timeout will be set (will wait indefinitely for success, unless request is force completed or canceled).
 @param block           The block to be executed when the request succeeds, fails, or times out. Three parameters are passed into the block:
 - The current location (the most recent one acquired, regardless of accuracy level), or nil if no valid location was acquired
 - The achieved accuracy for the current location (may be less than the desired accuracy if the request failed)
 - The request status (if it succeeded, or if not, why it failed)
 
 @return The location request ID, which can be used to force early completion or cancel the request while it is in progress.
 */
- (AdyLocationRequestID)requestLocationWithDesiredAccuracy:(AdyLocationAccuracy)desiredAccuracy
                                                    timeout:(NSTimeInterval)timeout
                                                      block:(AdyLocationRequestBlock)block
{
    return [self requestLocationWithDesiredAccuracy:desiredAccuracy
                                            timeout:timeout
                               delayUntilAuthorized:NO
                                              block:block];
}

/**
 Asynchronously requests the current location of the device using location services, optionally waiting until the user grants the app permission
 to access location services before starting the timeout countdown.
 
 @param desiredAccuracy      The accuracy level desired (refers to the accuracy and recency of the location).
 @param timeout              The maximum amount of time (in seconds) to wait for a location with the desired accuracy before completing. If
 this value is 0.0, no timeout will be set (will wait indefinitely for success, unless request is force completed or canceled).
 @param delayUntilAuthorized A flag specifying whether the timeout should only take effect after the user responds to the system prompt requesting
 permission for this app to access location services. If YES, the timeout countdown will not begin until after the
 app receives location services permissions. If NO, the timeout countdown begins immediately when calling this method.
 @param block                The block to be executed when the request succeeds, fails, or times out. Three parameters are passed into the block:
 - The current location (the most recent one acquired, regardless of accuracy level), or nil if no valid location was acquired
 - The achieved accuracy for the current location (may be less than the desired accuracy if the request failed)
 - The request status (if it succeeded, or if not, why it failed)
 
 @return The location request ID, which can be used to force early completion or cancel the request while it is in progress.
 */
- (AdyLocationRequestID)requestLocationWithDesiredAccuracy:(AdyLocationAccuracy)desiredAccuracy
                                                    timeout:(NSTimeInterval)timeout
                                       delayUntilAuthorized:(BOOL)delayUntilAuthorized
                                                      block:(AdyLocationRequestBlock)block
{
    if (desiredAccuracy == AdyLocationAccuracyNone) {
        NSAssert(desiredAccuracy != AdyLocationAccuracyNone, @"AdyLocationAccuracyNone is not a valid desired accuracy.");
        desiredAccuracy = AdyLocationAccuracyCity; // default to the lowest valid desired accuracy
    }
    
    AdyLocationRequest *locationRequest = [[AdyLocationRequest alloc] initWithType:AdyLocationRequestTypeSingle];
    locationRequest.delegate = self;
    locationRequest.desiredAccuracy = desiredAccuracy;
    locationRequest.timeout = timeout;
    locationRequest.block = block;
    
    BOOL deferTimeout = delayUntilAuthorized && ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined);
    if (!deferTimeout) {
        [locationRequest startTimeoutTimerIfNeeded];
    }
    
    [self addLocationRequest:locationRequest];
    
    return locationRequest.requestID;
}

/**
 Creates a subscription for location updates that will execute the block once per update indefinitely (until canceled), regardless of the accuracy of each location.
 This method instructs location services to use the highest accuracy available (which also requires the most power).
 If an error occurs, the block will execute with a status other than AdyLocationStatusSuccess, and the subscription will be canceled automatically.
 
 @param block The block to execute every time an updated location is available.
 The status will be AdyLocationStatusSuccess unless an error occurred; it will never be AdyLocationStatusTimedOut.
 
 @return The location request ID, which can be used to cancel the subscription of location updates to this block.
 */
- (AdyLocationRequestID)subscribeToLocationUpdatesWithBlock:(AdyLocationRequestBlock)block
{
    return [self subscribeToLocationUpdatesWithDesiredAccuracy:AdyLocationAccuracyRoom
                                                         block:block];
}

/**
 Creates a subscription for location updates that will execute the block once per update indefinitely (until canceled), regardless of the accuracy of each location.
 The specified desired accuracy is passed along to location services, and controls how much power is used, with higher accuracies using more power.
 If an error occurs, the block will execute with a status other than AdyLocationStatusSuccess, and the subscription will be canceled automatically.
 
 @param desiredAccuracy The accuracy level desired, which controls how much power is used by the device's location services.
 @param block           The block to execute every time an updated location is available. Note that this block runs for every update, regardless of
 whether the achievedAccuracy is at least the desiredAccuracy.
 The status will be AdyLocationStatusSuccess unless an error occurred; it will never be AdyLocationStatusTimedOut.
 
 @return The location request ID, which can be used to cancel the subscription of location updates to this block.
 */
- (AdyLocationRequestID)subscribeToLocationUpdatesWithDesiredAccuracy:(AdyLocationAccuracy)desiredAccuracy
                                                                 block:(AdyLocationRequestBlock)block
{
    AdyLocationRequest *locationRequest = [[AdyLocationRequest alloc] initWithType:AdyLocationRequestTypeSubscription];
    locationRequest.desiredAccuracy = desiredAccuracy;
    locationRequest.block = block;
    
    [self addLocationRequest:locationRequest];
    
    return locationRequest.requestID;
}

/**
 Creates a subscription for significant location changes that will execute the block once per change indefinitely (until canceled).
 If an error occurs, the block will execute with a status other than AdyLocationStatusSuccess, and the subscription will be canceled automatically.
 
 @param block The block to execute every time an updated location is available.
 The status will be AdyLocationStatusSuccess unless an error occurred; it will never be AdyLocationStatusTimedOut.
 
 @return The location request ID, which can be used to cancel the subscription of significant location changes to this block.
 */
- (AdyLocationRequestID)subscribeToSignificantLocationChangesWithBlock:(AdyLocationRequestBlock)block
{
    AdyLocationRequest *locationRequest = [[AdyLocationRequest alloc] initWithType:AdyLocationRequestTypeSignificantChanges];
    locationRequest.block = block;
    
    [self addLocationRequest:locationRequest];
    
    return locationRequest.requestID;
}

/**
 Immediately forces completion of the location request with the given requestID (if it exists), and executes the original request block with the results.
 This is effectively a manual timeout, and will result in the request completing with status AdyLocationStatusTimedOut.
 */
- (void)forceCompleteLocationRequest:(AdyLocationRequestID)requestID
{
    for (AdyLocationRequest *locationRequest in self.locationRequests) {
        if (locationRequest.requestID == requestID) {
            if (locationRequest.isRecurring) {
                // Recurring requests can only be canceled
                [self cancelLocationRequest:requestID];
            } else {
                [locationRequest forceTimeout];
                [self completeLocationRequest:locationRequest];
            }
            break;
        }
    }
}

/**
 Immediately cancels the location request with the given requestID (if it exists), without executing the original request block.
 */
- (void)cancelLocationRequest:(AdyLocationRequestID)requestID
{
    for (AdyLocationRequest *locationRequest in self.locationRequests) {
        if (locationRequest.requestID == requestID) {
            [locationRequest cancel];
            [self removeLocationRequest:locationRequest];
            break;
        }
    }
}

#pragma mark Internal methods

/**
 Adds the given location request to the array of requests, updates the maximum desired accuracy, and starts location updates if needed.
 */
- (void)addLocationRequest:(AdyLocationRequest *)locationRequest
{
    AdyLocationServicesState locationServicesState = [AdyLocationManager locationServicesState];
    if (locationServicesState == AdyLocationServicesStateDisabled ||
        locationServicesState == AdyLocationServicesStateDenied ||
        locationServicesState == AdyLocationServicesStateRestricted) {
        // No need to add this location request, because location services are turned off device-wide, or the user has denied this app permissions to use them
        [self completeLocationRequest:locationRequest];
        return;
    }
    
    switch (locationRequest.type) {
        case AdyLocationRequestTypeSingle:
        case AdyLocationRequestTypeSubscription:
        {
            AdyLocationAccuracy maximumDesiredAccuracy = AdyLocationAccuracyNone;
            // Determine the maximum desired accuracy for all existing location requests (does not include the new request we're currently adding)
            for (AdyLocationRequest *locationRequest in [self activeLocationRequestsExcludingType:AdyLocationRequestTypeSignificantChanges]) {
                if (locationRequest.desiredAccuracy > maximumDesiredAccuracy) {
                    maximumDesiredAccuracy = locationRequest.desiredAccuracy;
                }
            }
            // Take the max of the maximum desired accuracy for all existing location requests and the desired accuracy of the new request we're currently adding
            maximumDesiredAccuracy = MAX(locationRequest.desiredAccuracy, maximumDesiredAccuracy);
            [self updateWithMaximumDesiredAccuracy:maximumDesiredAccuracy];
            
            [self startUpdatingLocationIfNeeded];
        }
            break;
        case AdyLocationRequestTypeSignificantChanges:
            [self startMonitoringSignificantLocationChangesIfNeeded];
            break;
    }
    __Ady_GENERICS(NSMutableArray, AdyLocationRequest *) *newLocationRequests = [NSMutableArray arrayWithArray:self.locationRequests];
    [newLocationRequests addObject:locationRequest];
    self.locationRequests = newLocationRequests;
}
/**
 Removes a given location request from the array of requests, updates the maximum desired accuracy, and stops location updates if needed.
 */
- (void)removeLocationRequest:(AdyLocationRequest *)locationRequest
{
    __Ady_GENERICS(NSMutableArray, AdyLocationRequest *) *newLocationRequests = [NSMutableArray arrayWithArray:self.locationRequests];
    [newLocationRequests removeObject:locationRequest];
    self.locationRequests = newLocationRequests;
    
    switch (locationRequest.type) {
        case AdyLocationRequestTypeSingle:
        case AdyLocationRequestTypeSubscription:
        {
            // Determine the maximum desired accuracy for all remaining location requests
            AdyLocationAccuracy maximumDesiredAccuracy = AdyLocationAccuracyNone;
            for (AdyLocationRequest *locationRequest in [self activeLocationRequestsExcludingType:AdyLocationRequestTypeSignificantChanges]) {
                if (locationRequest.desiredAccuracy > maximumDesiredAccuracy) {
                    maximumDesiredAccuracy = locationRequest.desiredAccuracy;
                }
            }
            [self updateWithMaximumDesiredAccuracy:maximumDesiredAccuracy];
            
            [self stopUpdatingLocationIfPossible];
        }
            break;
        case AdyLocationRequestTypeSignificantChanges:
            [self stopMonitoringSignificantLocationChangesIfPossible];
            break;
    }
}

/**
 Returns the most recent current location, or nil if the current location is unknown, invalid, or stale.
 */
- (CLLocation *)currentLocation
{
    if (_currentLocation) {
        // Location isn't nil, so test to see if it is valid
        if (_currentLocation.coordinate.latitude == 0.0 && _currentLocation.coordinate.longitude == 0.0) {
            // The current location is invalid; discard it and return nil
            _currentLocation = nil;
        }
    }
    
    // Location is either nil or valid at this point, return it
    return _currentLocation;
}

/**
 Requests permission to use location services on devices with iOS 8+.
 */
- (void)requestAuthorizationIfNeeded
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_7_1
    // As of iOS 8, apps must explicitly request location services permissions. AdyLocationManager supports both levels, "Always" and "When In Use".
    // AdyLocationManager determines which level of permissions to request based on which description key is present in your app's Info.plist
    // If you provide values for both description keys, the more permissive "Always" level is requested.
    if (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_7_1 && [CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined) {
        BOOL hasAlwaysKey = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationAlwaysUsageDescription"] != nil;
        BOOL hasWhenInUseKey = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"NSLocationWhenInUseUsageDescription"] != nil;
        if (hasAlwaysKey) {
            [self.locationManager requestAlwaysAuthorization];
        } else if (hasWhenInUseKey) {
            [self.locationManager requestWhenInUseAuthorization];
        } else {
            // At least one of the keys NSLocationAlwaysUsageDescription or NSLocationWhenInUseUsageDescription MUST be present in the Info.plist file to use location services on iOS 8+.
            NSAssert(hasAlwaysKey || hasWhenInUseKey, @"To use location services in iOS 8+, your Info.plist must provide a value for either NSLocationWhenInUseUsageDescription or NSLocationAlwaysUsageDescription.");
        }
    }
#endif /* __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_7_1 */
}

/**
 Sets the CLLocationManager desiredAccuracy based on the given maximum desired accuracy (which should be the maximum desired accuracy of all active location requests).
 */
- (void)updateWithMaximumDesiredAccuracy:(AdyLocationAccuracy)maximumDesiredAccuracy
{
    switch (maximumDesiredAccuracy) {
        case AdyLocationAccuracyNone:
            break;
        case AdyLocationAccuracyCity:
            if (self.locationManager.desiredAccuracy != kCLLocationAccuracyThreeKilometers) {
                self.locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers;
            }
            break;
        case AdyLocationAccuracyNeighborhood:
            if (self.locationManager.desiredAccuracy != kCLLocationAccuracyKilometer) {
                self.locationManager.desiredAccuracy = kCLLocationAccuracyKilometer;
            }
            break;
        case AdyLocationAccuracyBlock:
            if (self.locationManager.desiredAccuracy != kCLLocationAccuracyHundredMeters) {
                self.locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
            }            break;
        case AdyLocationAccuracyHouse:
            if (self.locationManager.desiredAccuracy != kCLLocationAccuracyNearestTenMeters) {
                self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters;
            }            break;
        case AdyLocationAccuracyRoom:
            if (self.locationManager.desiredAccuracy != kCLLocationAccuracyBest) {
                self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
            }
            break;
        default:
            NSAssert(nil, @"Invalid maximum desired accuracy!");
            break;
    }
}

/**
 Inform CLLocationManager to start monitoring significant location changes.
 */
- (void)startMonitoringSignificantLocationChangesIfNeeded
{
    [self requestAuthorizationIfNeeded];
    
    NSArray *locationRequests = [self activeLocationRequestsWithType:AdyLocationRequestTypeSignificantChanges];
    if (locationRequests.count == 0) {
        [self.locationManager startMonitoringSignificantLocationChanges];
        if (self.isMonitoringSignificantLocationChanges == NO) {
        }
        self.isMonitoringSignificantLocationChanges = YES;
    }
}

/**
 Inform CLLocationManager to start sending us updates to our location.
 */
- (void)startUpdatingLocationIfNeeded
{
    [self requestAuthorizationIfNeeded];
    
    NSArray *locationRequests = [self activeLocationRequestsExcludingType:AdyLocationRequestTypeSignificantChanges];
    if (locationRequests.count == 0) {
        [self.locationManager startUpdatingLocation];
        if (self.isUpdatingLocation == NO) {
        }
        self.isUpdatingLocation = YES;
    }
}

- (void)stopMonitoringSignificantLocationChangesIfPossible
{
    NSArray *locationRequests = [self activeLocationRequestsWithType:AdyLocationRequestTypeSignificantChanges];
    if (locationRequests.count == 0) {
        [self.locationManager stopMonitoringSignificantLocationChanges];
        if (self.isMonitoringSignificantLocationChanges) {
        }
        self.isMonitoringSignificantLocationChanges = NO;
    }
}

/**
 Checks to see if there are any outstanding locationRequests, and if there are none, informs CLLocationManager to stop sending
 location updates. This is done as soon as location updates are no longer needed in order to conserve the device's battery.
 */
- (void)stopUpdatingLocationIfPossible
{
    NSArray *locationRequests = [self activeLocationRequestsExcludingType:AdyLocationRequestTypeSignificantChanges];
    if (locationRequests.count == 0) {
        [self.locationManager stopUpdatingLocation];
        if (self.isUpdatingLocation) {
        }
        self.isUpdatingLocation = NO;
    }
}

/**
 Iterates over the array of active location requests to check and see if the most recent current location
 successfully satisfies any of their criteria.
 */
- (void)processLocationRequests
{
    CLLocation *mostRecentLocation = self.currentLocation;
    
    for (AdyLocationRequest *locationRequest in self.locationRequests) {
        if (locationRequest.hasTimedOut) {
            // Non-recurring request has timed out, complete it
            [self completeLocationRequest:locationRequest];
            continue;
        }
        
        if (mostRecentLocation != nil) {
            if (locationRequest.isRecurring) {
                // This is a subscription request, which lives indefinitely (unless manually canceled) and receives every location update we get
                [self processRecurringRequest:locationRequest];
                continue;
            } else {
                // This is a regular one-time location request
                NSTimeInterval currentLocationTimeSinceUpdate = fabs([mostRecentLocation.timestamp timeIntervalSinceNow]);
                CLLocationAccuracy currentLocationHorizontalAccuracy = mostRecentLocation.horizontalAccuracy;
                NSTimeInterval staleThreshold = [locationRequest updateTimeStaleThreshold];
                CLLocationAccuracy horizontalAccuracyThreshold = [locationRequest horizontalAccuracyThreshold];
                if (currentLocationTimeSinceUpdate <= staleThreshold &&
                    currentLocationHorizontalAccuracy <= horizontalAccuracyThreshold) {
                    // The request's desired accuracy has been reached, complete it
                    [self completeLocationRequest:locationRequest];
                    continue;
                }
            }
        }
    }
}

/**
 Immediately completes all active location requests.
 Used in cases such as when the location services authorization status changes to Denied or Restricted.
 */
- (void)completeAllLocationRequests
{
    // Iterate through a copy of the locationRequests array to avoid modifying the same array we are removing elements from
    __Ady_GENERICS(NSArray, AdyLocationRequest *) *locationRequests = [self.locationRequests copy];
    for (AdyLocationRequest *locationRequest in locationRequests) {
        [self completeLocationRequest:locationRequest];
    }
}

/**
 Completes the given location request by removing it from the array of locationRequests and executing its completion block.
 */
- (void)completeLocationRequest:(AdyLocationRequest *)locationRequest
{
    if (locationRequest == nil) {
        return;
    }
    
    [locationRequest complete];
    [self removeLocationRequest:locationRequest];
    
    AdyLocationStatus status = [self statusForLocationRequest:locationRequest];
    CLLocation *currentLocation = self.currentLocation;
    AdyLocationAccuracy achievedAccuracy = [self achievedAccuracyForLocation:currentLocation];
    
    // AdyLocationManager is not thread safe and should only be called from the main thread, so we should already be executing on the main thread now.
    // dispatch_async is used to ensure that the completion block for a request is not executed before the request ID is returned, for example in the
    // case where the user has denied permission to access location services and the request is immediately completed with the appropriate error.
    dispatch_async(dispatch_get_main_queue(), ^{
        if (locationRequest.block) {
            locationRequest.block(currentLocation, achievedAccuracy, status);
        }
    });
    
}

/**
 Handles calling a recurring location request's block with the current location.
 */
- (void)processRecurringRequest:(AdyLocationRequest *)locationRequest
{
    NSAssert(locationRequest.isRecurring, @"This method should only be called for recurring location requests.");
    
    AdyLocationStatus status = [self statusForLocationRequest:locationRequest];
    CLLocation *currentLocation = self.currentLocation;
    AdyLocationAccuracy achievedAccuracy = [self achievedAccuracyForLocation:currentLocation];
    
    // No need for dispatch_async when calling this block, since this method is only called from a CLLocationManager callback
    if (locationRequest.block) {
        locationRequest.block(currentLocation, achievedAccuracy, status);
    }
}

/**
 Returns all active location requests with the given type.
 */
- (NSArray *)activeLocationRequestsWithType:(AdyLocationRequestType)locationRequestType
{
    return [self.locationRequests filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(AdyLocationRequest *evaluatedObject, NSDictionary *bindings) {
        return evaluatedObject.type == locationRequestType;
    }]];
}

/**
 Returns all active location requests excluding requests with the given type.
 */
- (NSArray *)activeLocationRequestsExcludingType:(AdyLocationRequestType)locationRequestType
{
    return [self.locationRequests filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(AdyLocationRequest *evaluatedObject, NSDictionary *bindings) {
        return evaluatedObject.type != locationRequestType;
    }]];
}

/**
 Returns the location manager status for the given location request.
 */
- (AdyLocationStatus)statusForLocationRequest:(AdyLocationRequest *)locationRequest
{
    AdyLocationServicesState locationServicesState = [AdyLocationManager locationServicesState];
    
    if (locationServicesState == AdyLocationServicesStateDisabled) {
        return AdyLocationStatusServicesDisabled;
    }
    else if (locationServicesState == AdyLocationServicesStateNotDetermined) {
        return AdyLocationStatusServicesNotDetermined;
    }
    else if (locationServicesState == AdyLocationServicesStateDenied) {
        return AdyLocationStatusServicesDenied;
    }
    else if (locationServicesState == AdyLocationServicesStateRestricted) {
        return AdyLocationStatusServicesRestricted;
    }
    else if (self.updateFailed) {
        return AdyLocationStatusError;
    }
    else if (locationRequest.hasTimedOut) {
        return AdyLocationStatusTimedOut;
    }
    
    return AdyLocationStatusSuccess;
}

/**
 Returns the associated AdyLocationAccuracy level that has been achieved for a given location,
 based on that location's horizontal accuracy and recency.
 */
- (AdyLocationAccuracy)achievedAccuracyForLocation:(CLLocation *)location
{
    if (!location) {
        return AdyLocationAccuracyNone;
    }
    
    NSTimeInterval timeSinceUpdate = fabs([location.timestamp timeIntervalSinceNow]);
    CLLocationAccuracy horizontalAccuracy = location.horizontalAccuracy;
    
    if (horizontalAccuracy <= kAdyHorizontalAccuracyThresholdRoom &&
        timeSinceUpdate <= kAdyUpdateTimeStaleThresholdRoom) {
        return AdyLocationAccuracyRoom;
    }
    else if (horizontalAccuracy <= kAdyHorizontalAccuracyThresholdHouse &&
             timeSinceUpdate <= kAdyUpdateTimeStaleThresholdHouse) {
        return AdyLocationAccuracyHouse;
    }
    else if (horizontalAccuracy <= kAdyHorizontalAccuracyThresholdBlock &&
             timeSinceUpdate <= kAdyUpdateTimeStaleThresholdBlock) {
        return AdyLocationAccuracyBlock;
    }
    else if (horizontalAccuracy <= kAdyHorizontalAccuracyThresholdNeighborhood &&
             timeSinceUpdate <= kAdyUpdateTimeStaleThresholdNeighborhood) {
        return AdyLocationAccuracyNeighborhood;
    }
    else if (horizontalAccuracy <= kAdyHorizontalAccuracyThresholdCity &&
             timeSinceUpdate <= kAdyUpdateTimeStaleThresholdCity) {
        return AdyLocationAccuracyCity;
    }
    else {
        return AdyLocationAccuracyNone;
    }
}

#pragma mark AdyLocationRequestDelegate method

- (void)locationRequestDidTimeout:(AdyLocationRequest *)locationRequest
{
    // For robustness, only complete the location request if it is still active (by checking to see that it hasn't been removed from the locationRequests array).
    for (AdyLocationRequest *activeLocationRequest in self.locationRequests) {
        if (activeLocationRequest.requestID == locationRequest.requestID) {
            [self completeLocationRequest:locationRequest];
            break;
        }
    }
}

#pragma mark CLLocationManagerDelegate methods

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    // Received update successfully, so clear any previous errors
    self.updateFailed = NO;
    
    CLLocation *mostRecentLocation = [locations lastObject];
    self.currentLocation = mostRecentLocation;
    
    // Process the location requests using the updated location
    [self processLocationRequests];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    self.updateFailed = YES;
    
    for (AdyLocationRequest *locationRequest in self.locationRequests) {
        if (locationRequest.isRecurring) {
            // Keep the recurring request alive
            [self processRecurringRequest:locationRequest];
        } else {
            // Fail any non-recurring requests
            [self completeLocationRequest:locationRequest];
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted) {
        // Clear out any active location requests (which will execute the blocks with a status that reflects
        // the unavailability of location services) since we now no longer have location services permissions
        [self completeAllLocationRequests];
    }
#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_7_1
    else if (status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse) {
#else
        else if (status == kCLAuthorizationStatusAuthorized) {
#endif /* __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_7_1 */
            
            // Start the timeout timer for location requests that were waiting for authorization
            for (AdyLocationRequest *locationRequest in self.locationRequests) {
                [locationRequest startTimeoutTimerIfNeeded];
            }
        }
    }
    
    @end
