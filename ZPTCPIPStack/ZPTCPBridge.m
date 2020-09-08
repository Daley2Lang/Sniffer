//
//  ZPTCPBridge.m
//  ZPTCPIPStack
//
//  Created by Qi Liu on 2020/9/8.
//  Copyright © 2020 zapcannon87. All rights reserved.
//

#import "ZPTCPBridge.h"
#import <ZPTCPIPStack/ZPTCPIPStack-Swift.h>

@implementation ZPTCPBridge

-(instancetype)init{
    if ([super init]) {
        JustSwift * vo = [JustSwift new];
        [vo justLog];
    
    }
    return self;
}

@end
