//
//  UserController.m
//  Ady
//
//  Created by Sahar Mostafa on 10/15/15.
//  Copyright © 2015 Sahar Mostafa. All rights reserved.
//
#import "UserController.h"
#import "ASStarRatingView.h"

@interface UserController ()
@property ASStarRatingView* staticStarRatingView;
@property (weak, nonatomic) IBOutlet UILabel *lblName;

@end

@implementation UserController

- (void)viewDidLoad {

    NSArray* arrNicknames = [NSArray arrayWithObjects: @"blueDragon", @"lookingForRainbow", @"cookieJar", @"I'mABigDeal", @"humsWhileShopping", @"loveToShop", @"theElegantOne", @"rainbowGazer", @"purpleDinasour", @"gigglesNTickles",
                             @"sunShine", nil];
    int random = arc4random()%[arrNicknames count];
    NSString *key = [arrNicknames objectAtIndex:random];
    _lblName.text = key;
    
    _staticStarRatingView = [[ASStarRatingView alloc]init];
    _staticStarRatingView.canEdit = NO;
    _staticStarRatingView.maxRating = 5;
    _staticStarRatingView.rating = 5;

    _staticStarRatingView.frame = CGRectMake(
                                          _lblName.frame.origin.x,
                                          _lblName.frame.origin.y+30,
                                          180,
                                          180);

    
    [self.view addSubview:_staticStarRatingView];

    
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)viewDidUnload
{
    [self setStaticStarRatingView:nil];
    [super viewDidUnload];
}

@end