//
//  PluginPlatformManager.h
//  ddDemo
//
//  Created by garin on 16/4/21.
//  Copyright © 2016年 DangDang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PluginPlatformManager : NSObject

+ (id)loadFramework:(NSString*)frameworkName; //获取framework返回对应的主类 //注意，防止使用出错，参数必须是 name.framework 这种带后缀的形式，且后缀名必须小写！插件名可以不小写


@end
