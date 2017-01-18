//
//  RDUserNotifyCenter.h
//  TestNCEDeom
//  version 1.0
//
//  Created by Radar on 2016/11/10.
//  Copyright © 2016年 Radar. All rights reserved.
//


//使用前，请先仔细阅读本类使用的相关说明，谢谢

//本类使用相关的问题:
//注1: 本类必须iOS10以上使用
//注2: 获取devicetoken的方法，仍然是在appDelegate中使用:
//   - (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken

//注3: 推送的payload中，所有字段必须不能重名，否则会选择最前面的字段使用
//注4: 本类默认使用attach字段当作推送过来的图片的指定字段，如果接口用了别的，让接口改吧，因为iOS10这个事情应该由客户端发起，并且之前也没有这个字段的需求，所以可以由客户端指定

//注5: attach字段所带过来的url里边，一定要带上类型后缀，比如.jpg .png .gif .mp3 .m4a .mp4 .m4v，不一定在最后，中间也可以。
//     本类会自动检测url中，只要出现了这几种类型，自会处理，如果什么都没带，按照.jpg处理
//     本类目前只处理图片类型，暂不支持视频和音频，以后版本升级再说

//注6: 在ServcieExtension修改过的内容，到ContentExtension里边用notification.request.content.xxx可以取到，但是不会修改到notification.request.content.userInfo里边
//     所以，尽量不要在这个地方进行content内容的修改，消息体内容尽量服务器来指定，包括挂载哪个category，最好也是服务器指定，因为userInfo这个信息，会在程序内多次传递并作为重要数据使用，中途修改会引起不安全因素
//     这个中间件的过程中，最好只用来下载attachment和其他需要下载的数据

//注7: 在info.plist里边添加 UNNotificationExtensionDefaultContentHidden项，并设定为YES，表示不显示原生alert信息，如果设定为NO，则显示原生alert信息

//注8: 绑定Action的工作放在containerApp是最合适的，因为需要在主工程中接收消息点击事件，然后在主工程中进行其他操作，actionid-categoryid-接收者，三者在同一个类中实现，比较合理，建议如此操作。
//     另外，在contentExtension被唤起之前，必须完成绑定，否则是看不到action的

//注9: 暂时不支持可输入文字形式的extension

//注10: 本类不是下载工具，只能简单下载一些固定URL的东西，比如数据或者图片，HTTP的header设定那些东西，不在本类范围内。如果需要使用，外面自行使用就行了。

//注11: 如果需要通过远程通知来使用本地图片做attachment，有两种处理方式：
//      1. 把该图片的 Target Membership 勾选上ServiceExtension. (用于同一张图片主app和扩展app都需要使用的情况)
//      2. 直接把要推送的图片在extension里边添加. (用于该图片只给扩展app使用)



//编译及调试相关问题:
//注1: 必须在每个Target里面，点击buildSettings 然后把Require Only App-Extension-Safe API 然后把YES改为NO，否则可能遇到如下问题：
//    'sharedApplication' is unavailable: not available on iOS (App Extension) - Use view controller based

//注2: 需要在container App的target->capabilities里边，打开如下三项：
//     1. Push Notifications
//     2. Background Modes -> Remote notifications
//     3. App Groups

//注3: 需要在每个Extension的target->capabilities里边，打开如下项:
//     1. App Groups

//注4: 要在每个target的info.plist里边添加app group项 //TO DO: 待定方案，暂时写在这里别忘了

//注5: 在本类之后新添加的contentExtension，需要把本类加入编译资源内，路径 contentExtension的target -> Build Phases -> Compile Sources 里边加入本类的编译











/*
 使用方法：
 1. 添加头文件: import "RDUserNotifyCenter"
 2. 添加代理： <RDUserNotifyCenterDelegate> 
 3. 注册通知：[[[RDUserNotifyCenter sharedCenter] registerUserNotification:self completion:<#^(BOOL success)completion#>]]; 
 4. 实现代理协议：- (void)didReceiveNotificationResponse:content:isLocal 方法，在这个方法里边处理接收到的通知
 
 4. [可选]绑定catgegory和action，使用如下一套的方法
    - (void)prepareBindingActions;
    - (void)appendAction:....
    - (void)bindingActions;
 
 5. [可选]规划本地通知，可在任何地方调用，和前面的顺序不能错
    使用schedule系列的方法
*/


/*远程推送的消息通知数据结构如下：
 
//现有payload格式
{
    "aps":
    {
        "alert":"xxxxx",
        "badge":"1",
        "sound":"default"
    },
    "goto_page" = "cms://page_id=14374"
}
 
//建议使用的新版payload格式，请注意，payload内部字段不可以相同
{
    "aps":
    {
        "alert":
        {
            "title":"我是原装标题",
            "subtitle":"我是副标题",
            "body":"it is a beautiful day"
        },
        "badge":1,
        "sound":"default",
        "mutable-content":"1",
        "category":"myNotificationCategory",
        "attach":"https://picjumbo.imgix.net/HNCK8461.jpg?q=40&w=200&sharp=30"
    },
    "goto_page":"cms://page_id=14374"
}
 
*/




#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>
#import <CoreLocation/CoreLocation.h>
#import <CommonCrypto/CommonDigest.h>




#pragma mark -
#pragma mark 一些通用的宏，用来全局使用，统一改动
//TO DO: 用程序获得group suit,才能全自动！
//TO DO: 想办法把这两个宏都弄成自动的才行
#define RDUserNotifyCenter_app_group_suite      @"group.com.dangdang.app"       //app group的suitname，必须和设置里边指定的相同
#define RDUserNotifyCenter_default_attach_key   @"attach"                       //通知payload里边，默认的attachment文件的字段，建议接口端按照这个字段设定，否则需要客户端由此宏修改来指定



@protocol RDUserNotifyCenterDelegate <NSObject>
@optional

//其他属性暂时不导出，这个地方直接返回response是因为里边带了太多信息，需要外面解析使用
//主要使用content和blocal参数，如果还不够，就去response里边找。
- (void)didReceiveNotificationResponse:(UNNotificationResponse*)response content:(UNNotificationContent*)content isLocal:(BOOL)blocal; 

@end



@interface RDUserNotifyCenter : NSObject <UNUserNotificationCenterDelegate> {
 
}
 
@property (assign) id <RDUserNotifyCenterDelegate> delegate;

//单实例
+ (instancetype)sharedCenter;





#pragma mark - 注册通知
//注册通知，本地+远程，需要在适当的时候调用一次本方法，app才会开启通知功能 //特别注意，此方法必须在程序启动的时候调用一次，不管以前是否注册过，否则会收不到通知 //单独写此方法是因为很多app在第一次使用的时候，要紧跟着开启定位，通知，数据，三个提醒，太烦人了以至于用户很容易点错。
- (void)registerUserNotification:(id)delegate completion:(void (^)(BOOL success))completion;



#pragma mark - 绑定action
//绑定action到指定的category上    //PS:目前暂不支持可以输入文字的anction样式   //PS:必须成套使用且只能使用一次，第二次使用会覆盖第一次
- (void)prepareBindingActions;
- (void)appendAction:(NSString *)actionID actionTitle:(NSString *)title options:(UNNotificationActionOptions)options toCategory:(NSString *)categoryID;
- (void)bindingActions; //prepare和binding必须配套使用


#pragma mark - 规划本地通知
//直接食用request规划本地通知
- (void)scheduleLocalNotify:(UNNotificationRequest *)request; //直接使用request规划本地通知，可以从外面直接做一个request调用。

//输入各种属性来规划本地通知  //PS: 全量方法，不建议使用这个
- (void)scheduleLocalNotify:(NSDateComponents *)fireDate        //触发日期安排        //注意：前三个是互斥的触发方式，只能有一个存在，同时共存当作没有处理，三个都不存在则返回规划失败
               timeInterval:(NSString *)fireTimeInterval        //触发延后时间安排
                    repeats:(BOOL)repeats
                      title:(NSString *)title
                   subtitle:(NSString *)subtitle
                       body:(NSString *)body
                 attachment:(NSString *)attachmentName        //附件图片的名字即可，里边会自动在bundle里边找
                 lauchImage:(NSString *)lauchImageName        //下拉放大的时候展示的图片，也是在bundle里边找, PS://如果想显示这个图片，则必须不使用自定义category，即需要categoryid=nil
                      sound:(NSString *)soundName
                      badge:(NSInteger)badge
                       info:(NSDictionary *)infoDic           //用来记录要传递的内容，跳转字典等都放这里
                useCategory:(NSString *)categoryid            //不是必须有，如果不绑定类型，则下拉推送模块不会出现下拉自定义扩展窗口
                   notifyid:(NSString *)notifyid
                 completion:(void(^)(NSError *error))completion;


//TO DO: 这里要尽量去掉上面那个复杂的方法，使用下面的组合方法来做本地通知，在info里边增加字段的支持

//规划本地通知 - 简化方法 - 根据日历规划
/*
 info:  //目前仅支持这几个种类，为了使用起来更方便，如果以后需要，再增加
 @{ 
     @"fire_timeinterval":@"5",              //触发时间延时 //注意，repeats的规则是下一次触发点是本次触发以后的timeinterval时间以后
     @"fire_msg":@"xxxxx",                   //触发时的显示信息
 
     @"link_url":@"xxxxx",                   //[可选]跳转字典
     @"category_id":@"xxxxx",                //[可选]此通知可以使用的下拉展开窗口的类型 
     @"attach":@"xxxxx",                     //[可选]通知带的图片附件
     @"repeats":@"1",                        //[可选]是否重复，使用0和1 //默认 0
     @"sound":@"xxxxx",                      //[可选]提示声音文件名，必须来自程序内置的，不写则使用默认声音
     ...                                     //[可选]可以随意添加更多数据，比如链接字典等，都会挂在userInfo里边   
  }
 */
- (void)scheduleTimeIntervalLocalNotify:(NSDictionary *)info completion:(void(^)(NSString *notifyid))completion; //只用info来规划本地通知, 规划成功以后会返回notifyid, 规划不成功则会返回nil，info也会加入到content.userInfo，用来接到通知以后使用


//规划本地通知 - 简化方法 - 根据日历规划
/*
 info:  //目前仅支持这几个种类，为了使用起来更方便，如果以后需要，再增加
 @{ 
    @"fire_date":@"YY-MM-dd HH:mm:ss",      //触发事件 //注意，repeats的规则是寻找下一次可以触发的时间点，所以如果每日触发，则不能写年、月、日，以此类推，以空格为界，分别向中间减少元素 如 MM-dd HH:mm  写的时候一定要注意前后不能出现空格，否则会出错
    @"fire_msg":@"xxxxx",                   //触发时的显示信息
 
    @"link_url":@"xxxxx",                   //[可选]跳转字典
    @"category_id":@"xxxxx",                //[可选]此通知可以使用的下拉展开窗口的类型 
    @"attach":@"xxxxx",                     //[可选]通知带的图片附件
    @"repeats":@"1",                        //[可选]是否重复，使用0和1 //默认 0
    @"sound":@"xxxxx",                      //[可选]提示声音文件名，必须来自程序内置的，不写则使用默认声音
    ...                                     //[可选]可以随意添加更多数据，比如链接字典等，都会挂在userInfo里边 
  }
*/
- (void)scheduleCalendarLocalNotify:(NSDictionary *)info completion:(void(^)(NSString *notifyid))completion; //只用info来规划本地通知, 规划成功以后会返回notifyid, 规划不成功则会返回nil，info也会加入到content.userInfo，用来接到通知以后使用




//撤销本地通知
+ (void)revokeNotifyWithIds:(NSArray *)notifyIds;               //根据通知的notifyid数组取消该通知，可以批量取消
+ (void)revokeAllNotifications;                                 //取消所有已经规划的消息通知

//检查通知是否已经添加
+ (void)checkHasScheduledById:(NSString *)notifyid feedback:(void(^)(BOOL scheduled))completion;             //通过notifyid判断是否已经添加





#pragma mark - 注册和规划使用通知相关的一些配套方法
+ (NSString *)md5NotifyID:(NSString *)notifyIdStr;                  //字符串做md5，仅供外部调用本类时，拼一个id，和本地做对应，不做别的用途，别处使用需要使用通用方法里边的
+ (NSDateComponents *)compoFromDateString:(NSString *)dateString;   //根据日期格式获得NSDateComponents对象 //格式必须为: @"YY-MM-dd HH:mm:ss"
+ (NSDateComponents *)compoFromDate:(NSDate *)date;                  //根据日期对象获得NSDateComponents对象


//PS:不用管payload的结构和层级关系，只管输入想要找的字段key就行了，里边会遍历找到对应的key
//PS:如果返回的类型是NSNumber类型，那么会自动转换成NSString类型输出，这么做的目的是因为有些字段在接口端可能会是数字也有的可能会是字符串推过来，所以统一进行一下强转，外面不要再判断类型了，这里只会返回NSString类型以及NSDiction和NSArray类型。
//PS:notify可以是UNNotificationRequest类型，也可以是UNNotification，也可以是UNNotificationContent类型，也可以是userInfo字典本身，方法内会自动检测
+ (id)getValueForKey:(NSString*)key inNotification:(id)notify;   //从notification中获取key对应的value





#pragma mark - 给UNNotificationServiceExtension配套的方法
//从通知中获取attachment，默认使用aps字典中的"attach"字段当作attachment，类型会自动检测，获取完成以后会用"attach"作为key来存储到group里边，
//PS: "attach" 由宏 RDUserNotifyCenter_default_attach_key指定，可通过修改宏来自定义attach的字段使用哪个，不需要指定路径，方法内部会自动检索
+ (void)downAndSaveAttachmentForNotifyRequest:(UNNotificationRequest *)request completion:(void(^)(UNNotificationAttachment *attach))completion;





#pragma mark - Extension间数据读取及共享相关方法
//数据下载和存储
+ (void)downLoadData:(NSString*)dataUrl completion:(void(^)(id data))completion;            //用dataUrl下载对应的数据并返回
+ (void)saveDataToGroup:(id)data forKey:(NSString*)key;                                     //根据通知的id存储数据到group里边

//下载dataUrl对应的数据，并存储到Group里边，默认使用dataUrl作为key存储，返回下载的数据
+ (void)downAndSaveDataToGroup:(NSString *)dataUrl completion:(void(^)(id data))completion;  

//下载dataUrl对应的数据，并存储到Group里边，优先使用forceKey作为key存储，如果forceKey不存在，则默认使用dataUrl作为key存储(此时效果同前一个方法)，返回下载的数据
+ (void)downAndSaveDataToGroup:(NSString *)dataUrl forceKey:(NSString*)forceKey completion:(void(^)(id data))completion; 

//下载dataUrl对应的数据，并存储到Group里边，优先使用forceKey+notifyid作为key存储，如果两者只存在其一，则使用存在的作为key存储，如果两者都不存在，则默认使用dataUrl作为key存储，然后返回下载的数据
+ (void)downAndSaveDataToGroup:(NSString *)dataUrl forceKey:(NSString*)forceKey forNotification:(id)notify completion:(void(^)(id data))completion; 

//下载一个数组的url对应的数据，并存储到Group里边，用每一个数据的url作为key存储，下载完成统一返回一次完成。
+ (void)downAndSaveDatasToGroup:(NSArray *)dataUrls completion:(void(^)(void))completion;    


//数据读取
//根据key从group里边取出存储的数据，key有可能是url也可能是自定义的, 如果明确知道存储的时候用的是什么key，那么notify字段可以设定为nil，反之则会模糊查找，使用key对应的url来读取。
//PS:notify可以是UNNotificationRequest类型，也可以是UNNotification，也可以是UNNotificationContent类型，也可以是userInfo字典本身，方法内会自动检测
+ (id)loadDataFromGroup:(NSString*)loadKey forNotification:(id)notify;  



//数据移除
+ (void)removeDataFromGroupForKey:(NSString*)key;   //根据key从group里边移除对应的数据





@end


