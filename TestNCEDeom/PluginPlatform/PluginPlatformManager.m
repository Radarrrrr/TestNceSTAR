//
//  PluginPlatformManager.m
//  ddDemo
//
//  Created by garin on 16/4/21.
//  Copyright © 2016年 DangDang. All rights reserved.
//

#import "PluginPlatformManager.h"

@implementation PluginPlatformManager

+ (id)loadFramework:(NSString *)frameworkName
{
    //说明：先在app bundle里边找，要是没有，就去document里边找，要是都没有，就返回nil
    if(!frameworkName || [frameworkName isEqualToString:@""]) return nil;
    
    //校验一下.framework后缀，保证不会使用出错
    NSRange range = [frameworkName rangeOfString:@".framework" options:NSBackwardsSearch];
    if(range.length == 0) 
    {
        NSLog(@"framework名称格式不正确！");
        return nil;
    }
    
    //创建framework寻找路径
    NSString *destLibPath = nil; 
    
    //1.在app bundle里找
    destLibPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:frameworkName];
    NSLog(@"appbundle里边的路径: %@",destLibPath);
    
    //判断一下bundle里有没有这个文件的存在，如果没有就到document里去找
    NSFileManager *manager = [NSFileManager defaultManager];
    if(![manager fileExistsAtPath:destLibPath]) 
    {
        NSLog(@"framework不在app bundle里，去document里边找找！");
        
        //2.在document里找
        NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
        if(!paths || [paths count] == 0) return nil;
        
        NSString *documentDirectory = [paths objectAtIndex:0];
        if(!documentDirectory || [documentDirectory isEqualToString:@""]) return nil;
        
        //拼接document中的framework路径
        destLibPath = [documentDirectory stringByAppendingPathComponent:frameworkName];
        NSLog(@"document里边的路径:%@",destLibPath);
        
        if(![manager fileExistsAtPath:destLibPath]) 
        {
            NSLog(@"framework也不在document里！返回没找到！");
            return nil;
        }
    }
    
    NSLog(@"找到的framework存放的路径: %@",destLibPath);
    

    //使用NSBundle加载动态库
    NSError *err = nil;
    
    NSBundle *frameworkBundle = [NSBundle bundleWithPath:destLibPath];
    if (frameworkBundle && [frameworkBundle loadAndReturnError:&err]) 
    {
        NSLog(@"framework加载成功！");
    }
    else
    {
        NSLog(@"framework加载失败！ error: %@", err);
        return nil;
    }
    
    //找到framework里边Info.plist，找到主类
    NSString *plistPath = [frameworkBundle pathForResource:@"Info" ofType:@"plist"];
    if(!plistPath || [plistPath isEqualToString:@""]) return nil;
    
    NSMutableDictionary *data = [[NSMutableDictionary alloc] initWithContentsOfFile:plistPath];
    
    NSString *principalClassString = data[@"NSPrincipalClass"];
    if(!principalClassString || [principalClassString isEqualToString:@""]) return nil;
    
    /*
     *通过NSClassFromString方式读取类
     *PacteraFramework　为动态库中入口类
     */
    Class pacteraClass = NSClassFromString(principalClassString);
    if(!pacteraClass)
    {
        NSLog(@"主类获取失败！");
        return nil;
    }
    
    /*
     *初始化方式采用下面的形式
     　alloc　init的形式是行不通的
     　同样，直接使用PacteraFramework类初始化也是不正确的
     *通过- (id)performSelector:(SEL)aSelector withObject:(id)object1 withObject:(id)object2;
     　方法调用入口方法（showView:withBundle:），并传递参数（withObject:self withObject:frameworkBundle）
     */
    NSObject *pacteraObject = [pacteraClass new];
    
    return pacteraObject;
}
  



@end
