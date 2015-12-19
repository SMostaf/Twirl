//
//  Item.h
//  Ady
//
//  Created by Sahar Mostafa on 10/16/15.
//  Copyright © 2015 Sahar Mostafa. All rights reserved.
//

#ifndef Style_h
#define Style_h

#import "Parse/Parse.h"
#import "DataInfo.h"

@interface StyleDetail : NSObject
@property NSArray* items;
@property NSInteger currentItemIndex;
@end


@interface StyleItems : NSObject

-(unsigned long) getLikesForSytle:(NSString*) styleId;
+(NSArray*) getItemsForStyle:(NSString*) styleId;
+(void) like:(NSString*) styleId itemId:(NSString*)itemId ownerId:(NSString*) ownerId;
-(void) purchase:(NSString*) styleId;
+(NSArray*) getStylesNearby:(CLLocation*) location;
+(DataInfo*) getCurrentStyleInfo;
-(void) saveStyle:(DataInfo*) info;

@end

#endif /* Style_h */
