//
//  connector.m
//  Layer to handle all requests to Parse cloud
//
//  Created by Sahar Mostafa on 11/20/14.
//  Copyright (c) 2014 Intel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "connector.h"

#define PARSE_APP_ID @"AotKeCXXy3BIbipBkHWI0hkEeBsrW3sGm738gPVT"
#define REST_KEY_ID  @"36tCnMKHTomoh588fsxhqZjf9bvDHelKwEsYr1rj"


@interface Connector()
-(void) doPost:(NSString*) url body: (NSString*) reqBody;
@property (nonatomic,strong) RespHandler respHandler;

@end

static NSString* serverURL = @"https://api.parse.com/1/functions/";

@implementation Connector

-(void) doPost:(NSString*) url body: (NSString*) reqBody {

    NSLog(@"jsonRequest is %@", reqBody);
    
    NSData *requestData = [reqBody dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableString* swUrl = [serverURL stringByAppendingString: url];
    NSLog(@"sending request to url: %@", swUrl);
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc]
                                    initWithURL:[NSURL
                                                 URLWithString:swUrl]];
    
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:PARSE_APP_ID forHTTPHeaderField:@"X-Parse-Application-Id"];
    [request setValue:REST_KEY_ID forHTTPHeaderField:@"X-Parse-REST-API-Key"];
    
    [request setHTTPBody: requestData];
    [request setTimeoutInterval:10];
    
    NSURLConnection *connection = [[NSURLConnection alloc]initWithRequest:request delegate:self startImmediately:NO];
    
    [connection scheduleInRunLoop:[NSRunLoop mainRunLoop]
                          forMode:NSDefaultRunLoopMode];
    [connection start];
}

// register token for purchaser
-(void) registerSender:(NSString*) tokenId name:(NSString*)name email:(NSString*) email completion:(RespHandler) handler {
    
    
    NSDictionary *jsonDict = [NSDictionary dictionaryWithObjects:
                              [NSArray arrayWithObjects:name, email,tokenId, nil]
                                                         forKeys:[NSArray arrayWithObjects:@"userName", @"userEmail",@"sourceId", nil]];
    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:&jsonError];
    if (jsonError != nil) {
        NSLog(@"Error parsing JSON.");
        return;
    }
    NSString* reqBody = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    if (reqBody == nil)
    {
        NSLog(@"Request Error body is nil!");
        return;
    }
    
    self.respHandler = handler;
    
    [self doPost: @"registerSender" body: reqBody];

    
}

// register bank info of recepient of transaction
-(void) registerRecepient:(NSString*) tokenId name:(NSString*)name email:(NSString*) email completion:(RespHandler) handler {
    
    
    NSDictionary *jsonDict = [NSDictionary dictionaryWithObjects:
                              [NSArray arrayWithObjects:name, email, tokenId, nil]
                                                         forKeys:[NSArray arrayWithObjects:@"userName", @"userEmail",@"sourceId", nil]];
    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:&jsonError];
    if (jsonError != nil) {
        NSLog(@"Error parsing JSON.");
        return;
    }
    NSString* reqBody = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    if (reqBody == nil)
    {
        NSLog(@"Request Error body is nil!");
        return;
    }
    
    self.respHandler = handler;
    
    [self doPost: @"registerRecepient" body: reqBody];
    
    
}

-(void) submitPay:(NSString*)userId token:(NSString*) token amount:(NSString*) amount
      completion:(RespHandler) handler
{
    
    NSLog(@"Sending new User request");
    
    
//    NSURL *url = [NSURL URLWithString:@"https://adylix.com/token"];
//    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
//    request.HTTPMethod = @"POST";
//    NSString *body     = [NSString stringWithFormat:@"stripeToken=%@", token.tokenId];
//    request.HTTPBody   = [body dataUsingEncoding:NSUTF8StringEncoding];
//    
//    [NSURLConnection sendAsynchronousRequest:request
//                                       queue:[NSOperationQueue mainQueue]
//                           completionHandler:^(NSURLResponse *response,
//                                               NSData *data,
//                                               NSError *error) {
//                               if (error) {
//                                   completion(PKPaymentAuthorizationStatusFailure);
//                               } else {
//                                   completion(PKPaymentAuthorizationStatusSuccess);
//                               }
//                           }];
    
    NSDictionary *jsonDict = [NSDictionary dictionaryWithObjects:
                              [NSArray arrayWithObjects:userId,token, amount, nil]
                                                         forKeys:[NSArray arrayWithObjects:@"userId",@"identifier", @"value",nil]];
    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:jsonDict options:0 error:&jsonError];
    if (jsonError != nil) {
        NSLog(@"Error parsing JSON.");
        return;
    }
    NSString* reqBody = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    if (reqBody == nil)
    {
        NSLog(@"Request Error body is nil!");
        return;
    }
    
    self.respHandler = handler;
    
    [self doPost: @"transfer" body: reqBody];
}


#pragma mark ConnectionResultHandler Delegate Methods

-(void) parseResponse:(NSData*) data {
    @try
    {
        NSError *error = nil;
        NSDictionary *jsonDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error != nil) {
            NSLog(@"Error parsing response JSON: %@", [error localizedDescription]);
            if (data == nil)
                NSLog(@" - Data object is nil!");
            else {
                NSString *dataStr = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
                NSLog(@" - Response data:%@:", dataStr);
            }
        }
        else {
            if(jsonDict[@"code"] != @"0")
            {
               // error = [[NSError alloc]init];
               // error.code = 1;
                self.respHandler(nil, error);
            }
         /*  switch(state)
            {
                // user registration
                case AWAITING_USER: {
                    
                    if ([jsonDict[@"userId"] length] > 0)
                    {
                        userId = jsonDict[@"userId"];
                       // [[[User alloc]init] saveUser:userId];
                    }
                    else
                    {
                        opState = CONNECTIONFAIL;
                        NSLog(@"Error in registering user");
                        self->lastServerError = [jsonDict objectForKey:@"error_msg"];
                    }
                }
                    
                break;
                // nearby query
                case AWAITING_LOC: {
                   
                    if ([tokenId length] > 0)
                    {
                        if ([jsonDict[@"client_token_b64"] length] > 0)// sw token response
                        {
                         //   CNResult* respData = [[CNResult alloc]init];
                            NSData* tokenData = [jsonDict[@"client_token_b64"] dataUsingEncoding:NSUTF8StringEncoding];
                          //  respData->data = [[NSString alloc] initWithData:tokenData encoding:NSUTF8StringEncoding];
                           // respData->state = PROVISIONED;
                            // delegate to model to save token
                           // [self->modelDelegate performSelector:@selector(receiveData:) withObject: respData];
                            return;

                        }
                    }
                    else
                    {
                        //self->tokenId = @"";
                        opState = PROVISIONEDFAIL;
                        NSLog(@"Error in receiving token from server, error code: %@", jsonDict[@"code"]);
                        self->lastServerError = [jsonDict objectForKey:@"error_msg"];
                    }

                }
                break;
                // query items for user
                case AWAITING_ITEMS: {
                    NSNumber* code = [jsonDict valueForKey:@"success"];
                    bool successVal = [code boolValue];
                    if(successVal == true) // no error codes
                    {
                        opState = VERIFIEDOTP;
                    }
                    else
                    {
                        //self->tokenId = @"";
                        opState = VERIFIEDOTPFAIL;
                        NSLog(@"Error in verifying otp from server");
                    }
                }
                break;
                // verifying attestation
                case AWAITING_VERIFYATTEST: {
                    bool successVal = [jsonDict objectForKey:@"success"];
                    if(successVal == true) // no error codes
                    {
                        opState = VERIFIEDATTESTATION;
                    }
                    else
                    {
                        opState = VERIFIEDATTESTATIONFAIL;
                        NSLog(@"Error in verifying attestation from server, error code: %@", jsonDict[@"code"]);
                        self->lastServerError = [jsonDict objectForKey:@"error_msg"];
                    }

                    
                }
                break;
                // Token resync
                case AWAITING_RESYNC: {
                    bool successVal = [jsonDict objectForKey:@"success"];
                    if (successVal) {
                        opState = RESYNCSUCCESSFUL;
                        tokenResyncDataB64 = [jsonDict objectForKey:@"resync_data_b64"];
                    }
                    else {
                        opState = RESYNCFAIL;
                        tokenResyncDataB64 = @"";
                        self->lastServerError = [jsonDict objectForKey:@"error_msg"];
                        NSLog(@"Failure to resync: %@ (code %@)", self->lastServerError, jsonDict[@"code"]);
                    }
                }
                break;
                default:
                {
                    opState = CONNECTIONFAIL;
                    NSLog(@"Error in receiving response from server");
                }

            }*/
        }
        
        self.respHandler(nil, error);
     //   NSNumber *opStateVal = [NSNumber numberWithInt: opState];
    //   [self.delegate performSelector:@selector(receiveStatus:) withObject: opStateVal];
        
    }
    @catch(...)
    {
//#TODO:
        //tokenId = @"";
       // NSNumber *opStateVal = [NSNumber numberWithInt: CONNECTIONFAIL];
     //  [self.delegate performSelector:@selector(receiveStatus:) withObject: opStateVal];
        NSError* error;
        self.respHandler(nil, error);
        NSLog(@"Exception in parsing response");
    }
}


#pragma mark NSURLConnection Delegate Methods

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self parseResponse:data];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection
willCacheResponse:(NSCachedURLResponse*)cachedResponse {
    // Return nil to indicate not necessary to store a cached response for this connection
    return nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    // The request is complete and data has been received
    // You can parse the stuff in your instance variable now
    //NSLog(@"Connection finished loading");
    
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    // The request has failed for some reason!
    // Check the error var
    NSLog(@"Received connection Error");
    NSNumber * connectError = [NSNumber numberWithInt:error.code];
    self.respHandler(nil, error);
   //[self.delegate performSelector:@selector(receiveStatus:) withObject:connectError];
}

-(NSString*)getTokenResyncDataB64 {
    return tokenResyncDataB64;
}

-(NSString*)getLastServerError {
    return lastServerError;
}

@end

