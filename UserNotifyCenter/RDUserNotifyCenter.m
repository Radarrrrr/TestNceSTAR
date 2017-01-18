//
//  RDUserNotifyCenter.m
//  TestNCEDeom
//
//  Created by Radar on 2016/11/10.
//  Copyright © 2016年 Radar. All rights reserved.
//

#import "RDUserNotifyCenter.h"


#define UNCSTRVALID(str)   [RDUserNotifyCenter checkStringValid:str]   //检查一个字符串是否有效


@interface RDUserNotifyCenter () 

@property (nonatomic, strong) NSMutableDictionary *bindingActionsDic; //数据结构：@{@"categoryID":@[action1, action2, ....], ....}

+ (NSString *)fileExtForURL:(NSString *)dataUrl;
+ (NSString *)notifyIdforNotification:(id)notify; //从通知中获取对应的notifyId，notify可以是UNNotificationRequest类型，也可以是UNNotification，也可以是UNNotificationContent类型，也可以直接就是字符串，方法内会自动检测

@end


@implementation RDUserNotifyCenter


- (id)init{
    self = [super init];
    if(self){
        //do something
    }
    return self;
}

+ (instancetype)sharedCenter
{
    static dispatch_once_t onceToken;
    static RDUserNotifyCenter *center;
    dispatch_once(&onceToken, ^{
        center = [[RDUserNotifyCenter alloc] init];
    });
    return center;
}




#pragma mark -
#pragma mark 本类内部方法
+ (NSDate*)dateFromString:(NSString*)dateString useFormat:(NSString*)format
{
    if(!dateString || [dateString isEqualToString:@""]) return nil;
    if(!format || [format isEqualToString:@""]) return nil;
    
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    [formatter setTimeZone:[NSTimeZone defaultTimeZone]];
    [formatter setDateFormat:format];
    
    NSDate* adate = [formatter dateFromString:dateString];
    
    return adate;
}
+ (NSString*)stringFromDate:(NSDate*)date useFormat:(NSString*)format
{
    //转化为要显示的时间格式如：@"MM-dd HH:mm"
    if(!date) return nil;
    if(!format || [format isEqualToString:@""]) return nil;
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setTimeZone:[NSTimeZone defaultTimeZone]];
    [formatter setDateFormat:format];
    
    NSString *dateString = [formatter stringFromDate:date];
    
    return dateString;
}

+ (BOOL)checkStringValid:(NSString *)string
{
    if(!string) return NO;
    if(![string isKindOfClass:[NSString class]]) return NO;
    if([string compare:@""] == NSOrderedSame) return NO;
    if([string compare:@"(null)"] == NSOrderedSame) return NO;
    
    return YES;
}


//在data数据源里，找到key对应的数据value，并返回 //PS: data只能是字典或数组类型
+ (id)getValueForKey:(NSString*)key inData:(id)data
{
    if(!data) return nil;
    if(!UNCSTRVALID(key)) return nil;
    if(![data isKindOfClass:[NSDictionary class]] && ![data isKindOfClass:[NSArray class]]) return nil;
    
    id value = nil;
    
    //开始解析
    if([data isKindOfClass:[NSDictionary class]])
    {
        NSArray *keys = [data allKeys];
        for(NSString *akey in keys)
        {
            if([akey compare:key] == NSOrderedSame)
            {
                value = [data objectForKey:key];
                break;
            }
            else
            {
                id adata = [data objectForKey:akey];
                id avalue = [self getValueForKey:key inData:adata];
                if(avalue)
                {
                    value = avalue;
                    break;
                }
            }
        }
    }
    else if([data isKindOfClass:[NSArray class]])
    {
        for(id adata in data)
        {
            id avalue = [self getValueForKey:key inData:adata];
            if(avalue)
            {
                value = avalue;
                break;
            }
        }
    }
    
    return value;
}





#pragma mark -
#pragma mark UNUserNotificationCenterDelegate 方法
- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler{
    
    //APP开启状态下，前台接到了通知
    //此方法用于处理在前台和后台接受到了通知以后，不同的UI样式和功能。
    //不过目前希望前台和后台接收到是处于相同的样式和内容。所以暂时不考虑此方法的扩展。
    
    if([notification.request.trigger isKindOfClass:[UNPushNotificationTrigger class]]) {
        NSLog(@"前台收到远程通知");
    }
    else {
        //判断为本地通知
        NSLog(@"前台收到本地通知");
    }
    
    //需要执行这个方法，选择是否提醒用户，有Badge、Sound、Alert三种类型可以设置
    //前台接收到通知以后，默认只提示声音和UI提醒，不做icon的红点提示。因为大部分app都是在进入app的时候会清理掉红点，这时候再加上，会有逻辑错误。
    completionHandler(UNNotificationPresentationOptionSound|UNNotificationPresentationOptionAlert); 
    
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void(^)())completionHandler{
    
    //通知的点击事件，不管是任何情况，点击通知都进这里
    //The method will be called on the delegate when the user responded to the notification by opening the application, dismissing the notification or choosing a UNNotificationAction. 
    //The delegate must be set before the application returns from applicationDidFinishLaunching:.
    
    BOOL blocal = YES;
    
    if([response.notification.request.trigger isKindOfClass:[UNPushNotificationTrigger class]]) {
        NSLog(@"收到远程通知并点击了");
        blocal = NO;
    }
    else {
        NSLog(@"收到本地通知并点击了");
        blocal = YES;
    }
    
    //返回给代理
    if(_delegate && [_delegate respondsToSelector:@selector(didReceiveNotificationResponse:content:isLocal:)])
    {
        [_delegate didReceiveNotificationResponse:response content:response.notification.request.content isLocal:blocal];
    }
    
    completionHandler();  //系统要求执行这个方法

}






#pragma mark -
#pragma mark 注册通知，绑定action，规划本地通知
- (void)registerUserNotification:(id)delegate completion:(void (^)(BOOL success))completion
{
    if ([[UIDevice currentDevice].systemVersion floatValue] < 10.0) 
    {
        NSLog(@"用错地方了，这个类只支持iOS10以上！");
        return;
    }
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        //设定自己的代理
        self.delegate = delegate;
        
        //注册通知
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        center.delegate = self;
        [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionBadge | UNAuthorizationOptionSound) completionHandler:^(BOOL granted, NSError * _Nullable error) {
            
            if(granted){ // 点击允许
                NSLog(@"消息通知注册成功");
            } else{ // 点击不允许
                NSLog(@"消息通知注册失败");
            }
            
            //触发appDelegate获取devicetoken
            [[UIApplication sharedApplication] registerForRemoteNotifications];
            
            if(completion)
            {
                completion(granted);
            }
            
        }];
    });
}


//绑定action到指定的category上，三套车
- (void)prepareBindingActions
{
    if(!_bindingActionsDic)
    {
        self.bindingActionsDic = [[NSMutableDictionary alloc] init];
    }
    [_bindingActionsDic removeAllObjects];
    
}
- (void)appendAction:(NSString *)actionID actionTitle:(NSString *)title options:(UNNotificationActionOptions)options toCategory:(NSString *)categoryID
{
    if(!categoryID || [categoryID isEqualToString:@""]) return;
    if(!actionID || [actionID isEqualToString:@""]) return;
    if(!_bindingActionsDic) return;
    
    //创建action
    UNNotificationAction *action = [UNNotificationAction actionWithIdentifier:actionID title:title options:options];
    if(!action) return;
    
    //在_bindingActionsDic里边找到categoryID对应的actions数组。
    NSMutableArray *actionsArr = [_bindingActionsDic objectForKey:categoryID];
    if(!actionsArr)
    {
        actionsArr = [[NSMutableArray alloc] init];
        [_bindingActionsDic setObject:actionsArr forKey:categoryID];
    }
    
    //地址操作，把action加入数组
    [actionsArr addObject:action];
    
}
- (void)bindingActions
{
    //数据结构：@{@"categoryID":@[action1, action2, ....], ....}
    if(!_bindingActionsDic || [_bindingActionsDic count] == 0) return;
    
    NSArray *categoryIds = [_bindingActionsDic allKeys];
    if(!categoryIds || [categoryIds count] == 0) return;
    
    NSMutableSet *cateSets = [[NSMutableSet alloc] init];
    
    for(NSString* cateid in categoryIds)
    {
        NSMutableArray *actionsArr = [_bindingActionsDic objectForKey:cateid];
        if(!actionsArr || [actionsArr count] == 0) break;
        
        UNNotificationCategory *category = [UNNotificationCategory categoryWithIdentifier:cateid actions:actionsArr  intentIdentifiers:@[] options:UNNotificationCategoryOptionCustomDismissAction];
        [cateSets addObject:category];
    }
    
    //设定categories
    [[UNUserNotificationCenter currentNotificationCenter] setNotificationCategories:cateSets];
    
    //再一次清空字典
    [_bindingActionsDic removeAllObjects];
}




- (void)scheduleLocalNotify:(UNNotificationRequest*)request
{
    if(!request) return;
    
    //把通知加到UNUserNotificationCenter, 到指定触发点会被触发
    [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
        //do sth for errorcode
    }];
}


- (void)scheduleLocalNotify:(NSDateComponents *)fireDate        //触发日期安排        //注意：前三个是互斥的触发方式，只能有一个存在，同时共存当作没有处理，三个都不存在则返回规划失败
               timeInterval:(NSString *)fireTimeInterval        //触发延后时间安排
                    repeats:(BOOL)repeats
                      title:(NSString *)title
                   subtitle:(NSString *)subtitle
                       body:(NSString *)body
                 attachment:(NSString *)attachmentName        //附件图片的名字即可，里边会自动在bundle里边找
                 lauchImage:(NSString *)lauchImageName        //下拉放大的时候展示的图片，也是在bundle里边找
                      sound:(NSString *)soundName
                      badge:(NSInteger)badge
                       info:(NSDictionary *)infoDic           //用来记录要传递的内容，跳转字典等都放这里
                useCategory:(NSString *)categoryid            //不是必须有，如果不绑定类型，则下拉推送模块不会出现下拉自定义扩展窗口
                   notifyid:(NSString *)notifyid
                 completion:(void(^)(NSError *error))completion
{
    NSError *error = nil;
    
    //做trigger //时间模式和地点模式是互斥的，以时间为优先，如果firedate为nil，再去考虑地点模式。暂不考虑两者共存的情况。//两种都没有，后面就不用做了
    UNNotificationTrigger *trigger = nil;
    if(fireDate)
    {
        trigger = (UNCalendarNotificationTrigger*)[UNCalendarNotificationTrigger triggerWithDateMatchingComponents:fireDate repeats:repeats];
    }
    else if(UNCSTRVALID(fireTimeInterval))
    {
        trigger = (UNTimeIntervalNotificationTrigger*)[UNTimeIntervalNotificationTrigger triggerWithTimeInterval:[fireTimeInterval doubleValue] repeats:repeats];
    }
    
    if(!trigger) 
    {
        if(completion)
        {
            error = [NSError errorWithDomain:@"schedule local notification" code:UNErrorCodeNotificationInvalidNoContent userInfo:@{@"error_msg":@"no firedate or region"}];
            completion(error);
        }
        return;
    }
    
    if(!UNCSTRVALID(notifyid))
    {
        if(completion)
        {
            error = [NSError errorWithDomain:@"schedule local notification" code:UNErrorCodeNotificationsNotAllowed userInfo:@{@"error_msg":@"need a notifyid"}];
            completion(error);
        }
        return;
    }
    
    
    //组合content，添加内容
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.title = title;
    content.subtitle = subtitle;
    content.body = body;
    content.badge = [NSNumber numberWithInteger:badge];
    
    if(!soundName || [soundName isEqualToString:@""])
    {
        content.sound = [UNNotificationSound defaultSound];
    }
    else
    {
        content.sound = [UNNotificationSound soundNamed:soundName];
    }
    
    if(attachmentName && ![attachmentName isEqualToString:@""])
    {
        //拆分附件名称
        NSString *name;
        NSString *type;
        
        NSRange range = [attachmentName rangeOfString:@"." options:NSBackwardsSearch];
        if(range.length != 0)
        {
            //有后缀
            name = [attachmentName substringToIndex:range.location];
            type = [attachmentName substringFromIndex:range.location+1];
        }
        else
        {
            //没写后缀，默认就是.jpg
            name = attachmentName;
            type = @"jpg";
        }
        
        NSError *aerror = nil;
        NSString *attachPath = [[NSBundle mainBundle] pathForResource:name ofType:type];   
        UNNotificationAttachment *attach = [UNNotificationAttachment attachmentWithIdentifier:@"" URL:[NSURL fileURLWithPath:attachPath] options:nil error:&aerror];
        if(!aerror) 
        {
            content.attachments = @[attach];
        }
    }
    
    content.categoryIdentifier = categoryid;
    content.launchImageName = lauchImageName;
    content.userInfo = infoDic;
    
    
    
    //创建本地通知
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:notifyid content:content trigger:trigger];
    
    //把通知加到UNUserNotificationCenter, 到指定触发点会被触发    
    [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
        
        if(!error) 
        {
            NSLog(@"本地通知添加成功！notifyid:%@", notifyid);
        }

        if(completion)
        {
            completion(error);
        }
    }];

}


- (void)scheduleTimeIntervalLocalNotify:(NSDictionary *)info completion:(void(^)(NSString *notifyid))completion
{
  /*
  info:  //目前仅支持这几个种类，为了使用起来更方便，如果以后需要，再增加
  @{ 
     @"fire_timeinterval":@"5",              //触发时间延时 //注意，repeats的规则是下一次触发点是本次触发以后的timeinterval时间以后
     @"fire_msg":@"xxxxx",                   //触发时的显示信息
     @"link_url":@"xxxxx",                   //[可选]跳转字典
     @"category_id":@"xxxxx",                //[可选]此通知可以使用的下拉展开窗口的类型 
     @"attach":@"xxxxx",                     //[可选]通知带的图片附件
     @"repeats":@"1",                        //[可选]是否重复，使用0和1 //默认 0
     @"sound":@"xxxxx"                       //[可选]提示声音文件名，必须来自程序内置的，不写则使用默认声音
  }
  */
    
    if(!info)
    {
        if(completion)
        {
            completion(nil);
        }
        return;
    }
    
    //前两种数据必须有
    NSString *fire_timeinterval = [info objectForKey:@"fire_timeinterval"];
    NSString *fire_msg = [info objectForKey:@"fire_msg"];
    if(!UNCSTRVALID(fire_timeinterval) || !UNCSTRVALID(fire_msg))
    {
        if(completion)
        {
            completion(nil);
        }
        return;
    }
    
    //做notifyid
    //把info中前四项内容取出来，拼在一起，中间$间隔，就是notifyid,   fire_timeinterval$fire_msg$link_url$category_id  供4个顺序不能变，有几个用几个
    NSString *notifyidStr = [NSString stringWithFormat:@"%@$%@", fire_timeinterval, fire_msg];
    
    NSString *link_url = [info objectForKey:@"link_url"];
    if(UNCSTRVALID(link_url))
    {
        notifyidStr = [notifyidStr stringByAppendingFormat:@"$%@", link_url];
    }
    
    NSString *category_id = [info objectForKey:@"category_id"];
    if(UNCSTRVALID(category_id))
    {
        notifyidStr = [notifyidStr stringByAppendingFormat:@"$%@", category_id];
    }
    
    //生成notifyid，使用MD5的形式，为了防止出现特殊符号
    NSString *notifyid = [RDUserNotifyCenter md5NotifyID:notifyidStr];  // <---这个就是通知的notifyid，也就是官方的requestid
    
    
    //用属性规划通知
    NSString *attach  = [info objectForKey:@"attach"];
    NSString *repeats = [info objectForKey:@"repeats"];
    NSString *sound   = [info objectForKey:@"sound"];
    
    BOOL brepeat = NO;
    if(UNCSTRVALID(repeats) && [repeats isEqualToString:@"1"]) 
    {
        brepeat = YES;
    }
    
        
    [self scheduleLocalNotify:nil 
                 timeInterval:fire_timeinterval
                      repeats:brepeat
                        title:nil 
                     subtitle:nil 
                         body:fire_msg 
                   attachment:attach 
                   lauchImage:nil 
                        sound:sound 
                        badge:1 
                         info:info 
                  useCategory:category_id 
                     notifyid:notifyid 
                   completion:^(NSError *error) {
                       
                       //规划成功，返回notifyid
                       if(completion)
                       {
                           if(!error)
                           {
                               completion(notifyid);
                           }
                           else
                           {
                               completion(nil);
                           }
                       }
                   }];
    
}


- (void)scheduleCalendarLocalNotify:(NSDictionary *)info completion:(void(^)(NSString *notifyid))completion
{
    /*
     info: 
     @{ 
         @"fire_date":@"YY-MM-dd HH:mm:ss",      //触发事件
         @"fire_msg":@"xxxxx",                   //触发时的显示信息
         @"link_url":@"xxxxx",                   //[可选]跳转字典
         @"category_id":@"xxxxx",                //[可选]此通知可以使用的下拉展开窗口的类型 
         @"attach":@"xxxxx",                     //[可选]通知带的图片附件
         @"repeats":@"1",                        //[可选]是否重复，使用0和1 //默认 0
         @"sound":@"xxxxx"                       //[可选]提示声音文件名，必须来自程序内置的，不写则使用默认声音
      }
    */
    
    if(!info)
    {
        if(completion)
        {
            completion(nil);
        }
        return;
    }
    
    //前两种数据必须有
    NSString *fire_date = [info objectForKey:@"fire_date"];
    NSString *fire_msg = [info objectForKey:@"fire_msg"];
    if(!UNCSTRVALID(fire_date) || !UNCSTRVALID(fire_msg))
    {
        if(completion)
        {
            completion(nil);
        }
        return;
    }
    
    //做notifyid
    //把info中前四项内容取出来，拼在一起，中间$间隔，就是notifyid,   fire_date$fire_msg$link_url$category_id  供4个顺序不能变，有几个用几个
    NSString *notifyidStr = [NSString stringWithFormat:@"%@$%@", fire_date, fire_msg];
    
    NSString *link_url = [info objectForKey:@"link_url"];
    if(UNCSTRVALID(link_url))
    {
        notifyidStr = [notifyidStr stringByAppendingFormat:@"$%@", link_url];
    }

    NSString *category_id = [info objectForKey:@"category_id"];
    if(UNCSTRVALID(category_id))
    {
        notifyidStr = [notifyidStr stringByAppendingFormat:@"$%@", category_id];
    }
    
    //生成notifyid，使用MD5的形式，为了防止出现特殊符号
    NSString *notifyid = [RDUserNotifyCenter md5NotifyID:notifyidStr];  // <---这个就是通知的notifyid，也就是官方的requestid
    
    
    //用属性规划通知
    NSString *attach  = [info objectForKey:@"attach"];
    NSString *repeats = [info objectForKey:@"repeats"];
    NSString *sound   = [info objectForKey:@"sound"];

    BOOL brepeat = NO;
    if(UNCSTRVALID(repeats) && [repeats isEqualToString:@"1"]) 
    {
        brepeat = YES;
    }

    
    NSDateComponents *datecompo = [RDUserNotifyCenter compoFromDateString:fire_date];
    
    [self scheduleLocalNotify:datecompo 
                 timeInterval:nil
                      repeats:brepeat
                        title:nil 
                     subtitle:nil 
                         body:fire_msg 
                   attachment:attach 
                   lauchImage:nil 
                        sound:sound 
                        badge:1 
                         info:info 
                  useCategory:category_id 
                     notifyid:notifyid 
                   completion:^(NSError *error) {
                       
                       //规划成功，返回notifyid
                       if(completion)
                       {
                           if(!error)
                           {
                               completion(notifyid);
                           }
                           else
                           {
                               completion(nil);
                           }
                       }
                   }];
    
}





+ (void)revokeNotifyWithIds:(NSArray *)notifyIds
{
    if(!notifyIds || notifyIds.count == 0) return;
    [[UNUserNotificationCenter currentNotificationCenter] removePendingNotificationRequestsWithIdentifiers:notifyIds];
}

+ (void)revokeAllNotifications
{
    [[UNUserNotificationCenter currentNotificationCenter] removeAllPendingNotificationRequests];
}

+ (void)checkHasScheduledById:(NSString *)notifyid feedback:(void(^)(BOOL scheduled))completion
{    
    if(!UNCSTRVALID(notifyid))
    {
        if(completion)
        {
            completion(NO);
        }
        return;
    }
    
    [[UNUserNotificationCenter currentNotificationCenter] getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> * _Nonnull requests) {
        
        BOOL bhave = NO;
        
        for(UNNotificationRequest *request in requests)
        {
            if([request.identifier isEqualToString:notifyid])
            {
                bhave = YES;
                break;
            }
        }
        
        if(completion)
        {
            completion(bhave);
        }
    }];
}






#pragma mark - 
#pragma mark 注册和规划使用通知相关的一些配套方法
+ (NSString *)md5NotifyID:(NSString *)notifyIdStr 
{
    const char *cStr =[notifyIdStr UTF8String];
    unsigned char result[16];
    CC_MD5(cStr, (int)strlen(cStr), result);
    return[NSString stringWithFormat:
           @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
           result[0], result[1], result[2], result[3],
           result[4], result[5], result[6], result[7],
           result[8], result[9], result[10], result[11],
           result[12], result[13], result[14], result[15]
           ];
}

+ (NSDateComponents *)compoFromDateString:(NSString *)dateString
{
    //YY-MM-dd HH:mm:ss  年月日和时分秒之间使用空格分隔，用来和目前常用格式标准统一
    if(!UNCSTRVALID(dateString)) return nil;
    
    //前后去空格,回车和换行，容错
    NSString *useString = [dateString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    NSArray *daytimeArr = [useString componentsSeparatedByString:@" "];
    if(!daytimeArr || daytimeArr.count < 1 || daytimeArr.count > 2) return nil;
    
    //组合compo
    NSDateComponents *compo = [[NSDateComponents alloc] init];
    
    NSString *daystr  = nil;  //YY-MM-dd
    NSString *timestr = nil;  //HH:mm:ss
    
    //注：只有年月日是无法提醒的，必须最低精确到小时才行
    if(daytimeArr.count == 1) //只有一段，说明只有时间，可能需要重复
    {
        daystr  = nil;
        timestr = [daytimeArr objectAtIndex:0]; 
    }
    else    //有两段，说明有年月日，并且也有时间，可能不需要重复
    {
        daystr  = [daytimeArr objectAtIndex:0];
        timestr = [daytimeArr objectAtIndex:1]; 
    }
    
    
    //设定日期
    if(UNCSTRVALID(daystr))
    {
        NSArray *dayArr = [daystr componentsSeparatedByString:@"-"];
        if(!dayArr || dayArr.count < 1 || dayArr.count > 3) return nil; //最多三个，已经进这里了，就不能没有了，外面可以没有
        
        //最少也是得有"天"
        compo.day = [(NSString*)[dayArr objectAtIndex:(dayArr.count-1)] integerValue];
        
        if(dayArr.count > 1)
        {
            compo.month = [(NSString*)[dayArr objectAtIndex:(dayArr.count-2)] integerValue];
        }
        
        if(dayArr.count == 3)
        {
            compo.year = [(NSString*)[dayArr objectAtIndex:0] integerValue];
        }
    }
    
    //设定时间
    if(UNCSTRVALID(timestr))
    {
        NSArray *timeArr = [timestr componentsSeparatedByString:@":"];
        if(!timeArr || timeArr.count < 1 || timeArr.count > 3) return nil; //最多三个，不能没有
        
        //最少也是得有"小时"
        compo.hour = [(NSString*)[timeArr objectAtIndex:0] integerValue]; 
        
        if(timeArr.count > 1)
        {
            compo.minute = [(NSString*)[timeArr objectAtIndex:1] integerValue];
        }
        
        if(timeArr.count == 3)
        {
            compo.second = [(NSString*)[timeArr objectAtIndex:2] integerValue];
        }
    }
    
    return compo;
}

+ (NSDateComponents *)compoFromDate:(NSDate *)date
{
    if(!date) return nil;
    
    NSString *dateString = [RDUserNotifyCenter stringFromDate:date useFormat:@"YY-MM-dd HH:mm:ss"];
    if(!UNCSTRVALID(dateString)) return nil;
    
    NSDateComponents *compo = [RDUserNotifyCenter compoFromDateString:dateString];
    return compo;
}


+ (id)getValueForKey:(NSString *)key inNotification:(id)notify
{
    if(!UNCSTRVALID(key)) return nil;
    if(!notify) return nil;
    
    //notify 可以是 UNNotificationRequest类型，也可以是UNNotification，也可以是UNNotificationContent，也可以是userInfo字典本身
    NSDictionary *infoDic = nil;
    
    if([notify isKindOfClass:[UNNotificationRequest class]])
    {
        infoDic = [(UNNotificationRequest*)notify content].userInfo;
    }
    else if([notify isKindOfClass:[UNNotificationContent class]])
    {
        infoDic = [(UNNotificationContent*)notify userInfo];
    }
    else if([notify isKindOfClass:[UNNotification class]])
    {
        infoDic = [(UNNotification*)notify request].content.userInfo;
    }
    else if([notify isKindOfClass:[NSDictionary class]])
    {
        infoDic = (NSDictionary*)notify;
    }
    
    //如果不是以上指定的四种类型，那么直接返回错误了
    if(!infoDic) return nil;
    
    //开始查找
    id value = [self getValueForKey:key inData:infoDic];
    
    //如果value不是字符串，则硬转为字符串返回
    if(value && [value isKindOfClass:[NSNumber class]])
    {
        value = [value stringValue];
    }
    
    return value;
}




#pragma mark - 
#pragma mark 给UNNotificationServiceExtension配套的方法
+ (void)downAndSaveAttachmentForNotifyRequest:(UNNotificationRequest *)request completion:(void(^)(UNNotificationAttachment *attach))completion
{
    //根据 RDUserNotifyCenter_default_attach_key 指定的attach字段找到并下载存储attachment
    if(!request || !request.content.userInfo)
    {
        if(completion)
        {
            completion(nil);
        }
        return;
    }
    
    //找到attach，虽然尽量限定aps里边，但是很难保证接口不任性，所以还是把所有的字段都检索一遍，找到attach字段，还得检查一下是否是url
    NSString *attachStr = [self getValueForKey:RDUserNotifyCenter_default_attach_key inNotification:request];
    if(!UNCSTRVALID(attachStr))    
    {
        //attach的数据value必须得是字符串
        if(completion)
        {
            completion(nil);
        }
        return;
    }
    
    //检查一下是否http或者https的url，如果是，就读取url，如果不是，就当作本地文件处理，查找本地文件里边是否有该文件，
    if([attachStr hasPrefix:@"http://"] || [attachStr hasPrefix:@"https://"])
    {
        //是url，下载并存储, 创建attachment并返回
        [self downLoadDataForURL:attachStr completion:^(NSURL *fileUrl) {
            
            //存储到group
            id data = [NSData dataWithContentsOfURL:fileUrl];
            [self saveDataToGroup:data forKey:attachStr];
            
            //创建attachment
            UNNotificationAttachment *attachment = [UNNotificationAttachment attachmentWithIdentifier:@"" URL:fileUrl options:nil error:nil];
            if(completion)
            {
                completion(attachment);
            }
        }];
    }
    else
    {
        //当app bundle里边的内置文件使用
        //拆分附件名称
        NSString *name;
        NSString *type;
        
        NSRange range = [attachStr rangeOfString:@"." options:NSBackwardsSearch];
        if(range.length != 0)
        {
            //有后缀
            name = [attachStr substringToIndex:range.location];
            type = [attachStr substringFromIndex:range.location+1];
        }
        else
        {
            //没写后缀，默认就是.jpg
            name = attachStr;
            type = @"jpg";
        }
        
        NSString *attachPath = [[NSBundle mainBundle] pathForResource:name ofType:type];   
        UNNotificationAttachment *attachment = [UNNotificationAttachment attachmentWithIdentifier:@"" URL:[NSURL fileURLWithPath:attachPath] options:nil error:nil];
        if(completion)
        {
            completion(attachment);
        }
    }
    
}

+ (void)downLoadDataForURL:(NSString*)dataUrl completion:(void(^)(NSURL *fileUrl))completion
{
    if(!UNCSTRVALID(dataUrl))
    {
        if(completion)
        {
            completion(nil);
        }
        return;
    }
    
    //下载数据，但不存储，返回fileurl文件地址路径
    NSURL *downUrl = [NSURL URLWithString:dataUrl];
    if(!downUrl)
    {
        if(completion)
        {
            completion(nil);
        }
        return;
    }
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    [[session downloadTaskWithURL:downUrl
                completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
                    
                    NSURL *fileUrl = nil;
                    
                    if(!error)
                    {
                        //先找到对应的类型及后缀
                        NSString *fileExt = [self fileExtForURL:dataUrl];
                        
                        NSFileManager *fileManager = [NSFileManager defaultManager];
                        fileUrl = [NSURL fileURLWithPath:[location.path stringByAppendingString:fileExt]];
                        BOOL ret = [fileManager moveItemAtURL:location toURL:fileUrl error:&error];
                        if(!ret)
                        {
                            fileUrl = nil;
                        }
                    }  
                    
                    //回上层
                    if(completion)
                    {
                        completion(fileUrl);
                    }
                    
                }] resume];
}

+ (NSString *)fileExtForURL:(NSString *)dataUrl 
{
    //把attachStr做全小写处理，用于在串里边找.jpg .png .gif .mp3 .m4a .mp4 .m4v这几种后缀，如果都没有，默认使用.jpg类型
    if(!UNCSTRVALID(dataUrl)) return nil;
    
    NSString *ext = @".jpg";
    NSString *useUrl = [dataUrl lowercaseString];
    
    
    NSArray *checkArr = @[@".jpg", @".png", @".gif", @".mp3", @".m4a", @".mp4", @".m4v"];
    
    for(NSString *check in checkArr)
    {
        NSRange range = [useUrl rangeOfString:check options:NSBackwardsSearch];
        if(range.length != 0)
        {
            ext = check;
            break;
        }
    }

    return ext;
}

+ (NSString *)notifyIdforNotification:(id)notify
{
    if(!notify) return nil;
 
    NSString *notifyId = nil;
    
    if([notify isKindOfClass:[UNNotificationRequest class]])
    {
        notifyId = [(UNNotificationRequest*)notify identifier];
    }
    else if([notify isKindOfClass:[UNNotification class]])
    {
        notifyId = [(UNNotification*)notify request].identifier;
    }
    else if([notify isKindOfClass:[NSString class]])
    {
        notifyId = (NSString*)notify;
    }
    
    return notifyId;
}




#pragma mark - Extension间数据读取及共享相关方法
+ (void)downLoadData:(NSString*)dataUrl completion:(void(^)(id data))completion
{
    if(!UNCSTRVALID(dataUrl))
    {
        if(completion)
        {
            completion(nil);
        }
        return;
    }
    
    //下载数据
    NSURL *downUrl = [NSURL URLWithString:dataUrl];
    if(!downUrl)
    {
        if(completion)
        {
            completion(nil);
        }
        return;
    }
    
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    [[session downloadTaskWithURL:downUrl
                completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
                    
                    id data = nil;
                    
                    if(!error)
                    {
                        data = [NSData dataWithContentsOfURL:location];
                    }  
                    
                    //回上层
                    if(completion)
                    {
                        completion(data);
                    }
                    
                }] resume];
}
+ (void)saveDataToGroup:(id)data forKey:(NSString*)key
{
    if(!UNCSTRVALID(key)) return;
    
    //对于推送来说，每次都推一样的东西是没意义的，所以根据url判断是否已经存在然后如果已经下载就不再下载的方式没有必要做。每次都下载并存储就对了。
    //TO DO: 这里还没有处理清空，可能会因为通知越来越多而导致越存越大
    //TO DO: 需要调研是否每次返回的location都是固定地址，然后生成的fileurl是否相同，关系到存储的东西是否会被下一次的覆盖
    //- (void)removePersistentDomainForName:(NSString *)domainName;
    
    //向group里边写入数据，group中所有的extension都可以使用
    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:RDUserNotifyCenter_app_group_suite];
    [shared setObject:data forKey:key];
    [shared synchronize];
}
+ (void)downAndSaveDataToGroup:(NSString *)dataUrl completion:(void(^)(id data))completion
{
    if(!UNCSTRVALID(dataUrl))
    {
        if(completion)
        {
            completion(nil);
        }
        return;
    }
    
    [self downLoadData:dataUrl completion:^(id data) {
        [self saveDataToGroup:data forKey:dataUrl];
        
        if(completion)
        {
            completion(data);
        }
    }];
}
+ (void)downAndSaveDataToGroup:(NSString *)dataUrl forceKey:(NSString*)forceKey completion:(void(^)(id data))completion
{
    if(!UNCSTRVALID(dataUrl))
    {
        if(completion)
        {
            completion(nil);
        }
        return;
    }
    
    [self downLoadData:dataUrl completion:^(id data) {
        
        NSString *useKey = dataUrl;
        if(UNCSTRVALID(forceKey))
        {
            useKey = forceKey;
        }
            
        [self saveDataToGroup:data forKey:useKey];
        
        if(completion)
        {
            completion(data);
        }
    }];
}
+ (void)downAndSaveDataToGroup:(NSString *)dataUrl forceKey:(NSString*)forceKey forNotification:(id)notify completion:(void(^)(id data))completion
{
    if(!UNCSTRVALID(dataUrl))
    {
        if(completion)
        {
            completion(nil);
        }
        return;
    }
    
    [self downLoadData:dataUrl completion:^(id data) {
        
        NSString *useKey = dataUrl;
        
        NSString *notifyId = [self notifyIdforNotification:notify];
        
        if(UNCSTRVALID(forceKey) && UNCSTRVALID(notifyId))
        {
            useKey = [NSString stringWithFormat:@"%@_%@", forceKey, notifyId];
        }
        else if(UNCSTRVALID(forceKey))
        {
            useKey = forceKey;
        }
        else if(UNCSTRVALID(notifyId))
        {
            useKey = notifyId;
        }
        
        [self saveDataToGroup:data forKey:useKey];
        
        if(completion)
        {
            completion(data);
        }
    }];
}

+ (void)downAndSaveDatasToGroup:(NSArray *)dataUrls completion:(void(^)(void))completion
{
    if(!dataUrls || [dataUrls count] == 0) 
    {
        if(completion)
        {
            completion();
        }
        return;
    }
    
    //group下载
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_group_t group = dispatch_group_create();
    
    for(NSString *url in dataUrls)
    {
        if(!UNCSTRVALID(url)) break;
        
        dispatch_group_async(group, queue, ^{
            id data = [NSData dataWithContentsOfURL:[NSURL URLWithString:url]];
            [self saveDataToGroup:data forKey:url];
            
            NSLog(@"下载并保存完成: %@", url);
        });
    }
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSLog(@"数组URL全部下载并保存完成!");
        
        if(completion)
        {
            completion();
        }
    });
        
}


+ (id)loadDataFromGroup:(NSString*)urlorKey
{
    if(!UNCSTRVALID(urlorKey)) return nil;
    
    //从group里边取出数据使用
    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:RDUserNotifyCenter_app_group_suite];
    id data = [shared objectForKey:urlorKey];
    
    return data;
}


+ (id)loadDataFromGroup:(NSString*)loadKey forNotification:(id)notify
{    
    id data = nil;
    
    NSString *notifyId = [self notifyIdforNotification:notify];
    
    //先按照loadkey+notifyId的组合判断条件来读取
    if(UNCSTRVALID(loadKey) && UNCSTRVALID(notifyId))
    {
        NSString *useKey = [NSString stringWithFormat:@"%@_%@", loadKey, notifyId];
        data = [self loadDataFromGroup:useKey];
        if(data) return data;
    }
    
    //如果组合的没有，再按照直接key存储的读取
    if(UNCSTRVALID(loadKey))
    {
        data = [self loadDataFromGroup:loadKey];
        if(data) return data;
    }
    
    //loadKey也没有，看看notifyId有没有
    if(UNCSTRVALID(notifyId))
    {
        data = [self loadDataFromGroup:notifyId];
        if(data) return data;
    }
    
    //如果直接读取不出来，再通过url读取
    if(UNCSTRVALID(loadKey) && notify)
    {
        //看是不是按照url存的，找到loadkey对应的url，如果loadkey也不是payload里边的key，那么就返回空了
        id value = [RDUserNotifyCenter getValueForKey:loadKey inNotification:notify];
        if(UNCSTRVALID(value))
        {
            data = [self loadDataFromGroup:(NSString*)value];
        }
    }
    
    return data;
}


+ (void)removeDataFromGroupForKey:(NSString*)key
{
    if(!UNCSTRVALID(key)) return;
    
    NSUserDefaults *shared = [[NSUserDefaults alloc] initWithSuiteName:RDUserNotifyCenter_app_group_suite];
    [shared removeObjectForKey:key];
    [shared synchronize];
}



@end



