//
//  Tool.m
//  Sniffer
//
//  Created by Qi Liu on 2020/9/11.
//  Copyright © 2020 zapcannon87. All rights reserved.
//

#import "Tool.h"
#include <ifaddrs.h>
#include <arpa/inet.h>
#include <net/if.h>


#define IOS_CELLULAR    @"pdp_ip0"
#define IOS_WIFI        @"en0"
#define IOS_VPN         @"utun0"

#define IP_ADDR_IPv4    @"ipv4"
#define IP_ADDR_IPv6    @"ipv6"
@implementation Tool


//private ip
+(NSString *)getIPAddress:(int)preferNet
{
    @try {
        NSArray *searchArray = nil;
        switch (preferNet) {
            case 0:
                searchArray=@[ IOS_CELLULAR @"/" IP_ADDR_IPv4];
//                 searchArray=@[ IOS_CELLULAR @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6 ];
                break;
            case 1:
                searchArray=@[ IOS_WIFI @"/" IP_ADDR_IPv4, IOS_WIFI @"/" IP_ADDR_IPv6 ];
                break;
            case 2:
                searchArray=@[ IOS_VPN @"/" IP_ADDR_IPv4, IOS_VPN @"/" IP_ADDR_IPv6 ];
                break;
            default:
                searchArray=@[ IOS_CELLULAR @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6, IOS_WIFI @"/" IP_ADDR_IPv4, IOS_WIFI @"/" IP_ADDR_IPv6, IOS_VPN @"/" IP_ADDR_IPv4, IOS_VPN @"/" IP_ADDR_IPv6 ] ;
                break;
        }
        
        NSDictionary *addresses = [self getIPAddresses];
        
        if (addresses) {
             __block  NSMutableDictionary * dic = [NSMutableDictionary dictionary];
            [addresses enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                NSString * keyStr = [NSString stringWithFormat:@"%@",key];
                if ([keyStr rangeOfString:@"ipv4"].location != NSNotFound) {
                    [dic setValue:obj forKey:keyStr];
                }
            }];
             NSLog(@"当前的所有地址:\n%@",dic);
        }
        
       
        
        __block NSString *address;
        [searchArray enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop)
         {
            address = addresses[key];
            if(address) *stop = YES;
        } ];
        return address ? address : @"0.0.0.0";
    } @catch (NSException *exception) {
        return @"0.0.0.0";
    }
    
}

+(NSDictionary *)getIPAddresses{
    @try {
        
        /*
         lo0         //本地ip, 127.0.0.1
         en0        //局域网ip, 192.168.1.23
         pdp_ip0  //WWAN地址，即3G ip,
         bridge0  //桥接、热点ip，172.20.10.1
         */
        
        NSMutableDictionary *addresses = [NSMutableDictionary dictionaryWithCapacity:8];
        // retrieve the current interfaces - returns 0 on success
        struct ifaddrs *interfaces;
        if(!getifaddrs(&interfaces)) {
            // Loop through linked list of interfaces
            struct ifaddrs *interface;
            for(interface=interfaces; interface; interface=interface->ifa_next) {
                if(!(interface->ifa_flags & IFF_UP) /* || (interface->ifa_flags & IFF_LOOPBACK) */ ) {
                    continue; // deeply nested code harder to read
                }
                const struct sockaddr_in *addr = (const struct sockaddr_in*)interface->ifa_addr;
                char addrBuf[ MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN) ];
                if(addr && (addr->sin_family==AF_INET || addr->sin_family==AF_INET6)) {
                    NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
                    NSString *type;
                    if(addr->sin_family == AF_INET) {
                        if(inet_ntop(AF_INET, &addr->sin_addr, addrBuf, INET_ADDRSTRLEN)) {
                            type = IP_ADDR_IPv4;
                        }
                    } else {
                        const struct sockaddr_in6 *addr6 = (const struct sockaddr_in6*)interface->ifa_addr;
                        if(inet_ntop(AF_INET6, &addr6->sin6_addr, addrBuf, INET6_ADDRSTRLEN)) {
                            type = IP_ADDR_IPv6;
                        }
                    }
                    if(type) {
                        NSString *key = [NSString stringWithFormat:@"%@/%@", name, type];
                        addresses[key] = [NSString stringWithUTF8String:addrBuf];
                    }
                }
            }
            // Free memory
            freeifaddrs(interfaces);
        }
        return [addresses count] ? addresses : nil;
    } @catch (NSException *exception) {
        return nil;
    }
    
}
@end
