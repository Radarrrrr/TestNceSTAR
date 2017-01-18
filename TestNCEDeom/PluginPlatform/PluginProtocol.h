//
//  PluginProtocol.h
//  ddDemo
//
//  Created by garin on 16/4/28.
//  Copyright © 2016年 DangDang. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol PluginProtocol <NSObject>

@optional

@property (nonatomic,strong) NSDictionary *initData;

@end
