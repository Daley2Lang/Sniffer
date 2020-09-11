//
//  Tool.h
//  Sniffer
//
//  Created by Qi Liu on 2020/9/11.
//  Copyright © 2020 zapcannon87. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface Tool : NSObject
+(NSString *)getIPAddress:(int)preferNet;
@end

NS_ASSUME_NONNULL_END
