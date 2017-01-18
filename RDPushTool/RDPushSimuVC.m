//
//  RDPushSimuVC.m
//  TestNCEDeom
//
//  Created by Radar on 2016/12/19.
//  Copyright © 2016年 Radar. All rights reserved.
//

#import "RDPushSimuVC.h"
#import <AudioToolbox/AudioToolbox.h>


#define PSRGB(r, g, b)        [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:1.0]
#define PSRGBS(x)             [UIColor colorWithRed:x/255.0 green:x/255.0 blue:x/255.0 alpha:1.0]

#define savekey_payload_customize     @"savekey payload customize"      //自定义payload存储key
#define savekey_devicetoken_customize @"savekey devicetoken customize"  //自定义devicetoken存储key
#define savekey_localapp_devicetoken  @"savekey localapp devicetoken"   //本机自己app获取的devicetoken存储key



@interface RDPushSimuVC () <UITextViewDelegate>

@property (nonatomic, strong) UIButton *connectBtn;
@property (nonatomic, strong) UIButton *disConnectBtn;
@property (nonatomic, strong) UITextView *payloadTextView;
@property (nonatomic, strong) UIButton *recoverPayloadBtn;
@property (nonatomic, strong) UILabel *tokenField;
@property (nonatomic, strong) UIButton *pushBtn;
@property (nonatomic, strong) UITextView *logTextView;
@property (nonatomic, strong) NSString *logString;

@end

@implementation RDPushSimuVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
//#ifdef DEBUG
//    
//#else
//    
//#endif
    
    self.navigationItem.title = @"RDPush Simulator";
    self.view.backgroundColor = [UIColor whiteColor];
    
    
    //注册消息监听器
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveConnectStateNotify:) name:NOTIFICATION_RDPUSHTOOL_REPORT object:nil];
        
    //连接按钮
    self.connectBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _connectBtn.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 35);
    _connectBtn.backgroundColor = PSRGBS(130);
    [_connectBtn setTitle:@"Connect to APNs." forState:UIControlStateNormal];
    [_connectBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _connectBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [_connectBtn addTarget:self action:@selector(connectAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_connectBtn];
    
    //断开连接按钮
    self.disConnectBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _disConnectBtn.frame = CGRectMake([UIScreen mainScreen].bounds.size.width, 0, 70, 35);
    _disConnectBtn.backgroundColor = [UIColor darkGrayColor];
    [_disConnectBtn setTitle:@"disconnect" forState:UIControlStateNormal];
    [_disConnectBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _disConnectBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [_disConnectBtn addTarget:self action:@selector(disConnectAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_disConnectBtn];
    
    
    //payload内容输入
    UILabel *payloadL = [[UILabel alloc] initWithFrame:CGRectMake(10, CGRectGetMaxY(_connectBtn.frame), 200, 20)];
    payloadL.text = @"payload:";
    payloadL.textColor = PSRGBS(50);
    payloadL.font = [UIFont boldSystemFontOfSize:14.0];
    [self.view addSubview:payloadL];
    
    self.payloadTextView = [[UITextView alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(payloadL.frame)-5, [UIScreen mainScreen].bounds.size.width-25, 296)];
    _payloadTextView.backgroundColor = [UIColor clearColor];//PSRGBS(230);
    _payloadTextView.editable = YES;
    _payloadTextView.textColor = PSRGBS(100);
    _payloadTextView.font = [UIFont systemFontOfSize:13.0];
    _payloadTextView.text = [self getUseablePayload];
    _payloadTextView.delegate = self;
    [self.view addSubview:_payloadTextView];
    
    self.recoverPayloadBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _recoverPayloadBtn.frame = CGRectMake(CGRectGetMaxX(_payloadTextView.frame)-100, CGRectGetMaxY(_payloadTextView.frame)-30, 100, 30);
    _recoverPayloadBtn.backgroundColor = PSRGBS(200);
    [_recoverPayloadBtn setTitle:@"default payload" forState:UIControlStateNormal];
    [_recoverPayloadBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _recoverPayloadBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12];
    [_recoverPayloadBtn addTarget:self action:@selector(recoverPayloadAction:) forControlEvents:UIControlEventTouchUpInside];
    _recoverPayloadBtn.alpha = 0.0;
    [self.view addSubview:_recoverPayloadBtn];
    
    [self addLineBelow:_payloadTextView];
    

    //devicetoken显示区域
    UILabel *tokenL = [[UILabel alloc] initWithFrame:CGRectMake(10, CGRectGetMaxY(_payloadTextView.frame)+5, 120, 15)];
    tokenL.text = @"token to push:";
    tokenL.textColor = PSRGBS(50);
    tokenL.backgroundColor = [UIColor clearColor];
    tokenL.font = [UIFont boldSystemFontOfSize:14.0];
    [self.view addSubview:tokenL];
    
    self.tokenField = [[UILabel alloc] initWithFrame:CGRectMake(10, CGRectGetMaxY(tokenL.frame), 250, 35)];
    _tokenField.backgroundColor = [UIColor clearColor];
    _tokenField.textColor = PSRGBS(150);
    _tokenField.font = [UIFont systemFontOfSize:11.5];
    _tokenField.numberOfLines = 0;
    _tokenField.text = [self getUseableDeviceToken];
    [self.view addSubview:_tokenField];
    
    
    UIButton *pasteTokenBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    pasteTokenBtn.frame = CGRectMake(CGRectGetMaxX(_tokenField.frame)+10, CGRectGetMaxY(_payloadTextView.frame), ([UIScreen mainScreen].bounds.size.width-CGRectGetMaxX(_tokenField.frame)-10)/2, 55);
    pasteTokenBtn.backgroundColor = [UIColor clearColor];
    [pasteTokenBtn setTitle:@"paste" forState:UIControlStateNormal];
    [pasteTokenBtn setTitleColor:PSRGBS(100) forState:UIControlStateNormal];
    pasteTokenBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [pasteTokenBtn addTarget:self action:@selector(pasteTokenAction:) forControlEvents:UIControlEventTouchUpInside];
    pasteTokenBtn.layer.borderColor = [UIColor colorWithWhite:0.9f alpha:0.9f].CGColor;
    pasteTokenBtn.layer.borderWidth = 0.5f;
    [self.view addSubview:pasteTokenBtn];
    
    UIButton *recoverTokenBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    recoverTokenBtn.frame = CGRectMake(CGRectGetMaxX(pasteTokenBtn.frame), CGRectGetMinY(pasteTokenBtn.frame), CGRectGetWidth(pasteTokenBtn.frame), CGRectGetHeight(pasteTokenBtn.frame));
    recoverTokenBtn.backgroundColor = [UIColor clearColor];
    [recoverTokenBtn setTitle:@"default" forState:UIControlStateNormal];
    [recoverTokenBtn setTitleColor:PSRGBS(100) forState:UIControlStateNormal];
    recoverTokenBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [recoverTokenBtn addTarget:self action:@selector(recoverTokenAction:) forControlEvents:UIControlEventTouchUpInside];
    recoverTokenBtn.layer.borderColor = [UIColor colorWithWhite:0.9f alpha:0.9f].CGColor;
    recoverTokenBtn.layer.borderWidth = 0.5f;
    [self.view addSubview:recoverTokenBtn];
    
    [self addLineBelow:_tokenField];
    
    
    //状态显示
    UILabel *logL = [[UILabel alloc] initWithFrame:CGRectMake(10, CGRectGetMaxY(_tokenField.frame)+3, [UIScreen mainScreen].bounds.size.width, 20)];
    logL.text = @"console:";
    logL.textColor = PSRGBS(50);
    logL.font = [UIFont boldSystemFontOfSize:14.0];
    [self.view addSubview:logL];
    
    self.logTextView = [[UITextView alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(logL.frame), [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height-64-CGRectGetMaxY(logL.frame)-50)];
    _logTextView.backgroundColor = PSRGBS(240);
    _logTextView.editable = NO;
    _logTextView.textColor = PSRGBS(100);
    _logTextView.font = [UIFont systemFontOfSize:12.0];
    [self.view addSubview:_logTextView];
    
    self.logString = @"welcome to push simulator!";
    _logTextView.text = _logString;
    
    UIButton *clearLogBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    clearLogBtn.frame = CGRectMake(CGRectGetMaxX(_logTextView.frame)-30, CGRectGetMinY(_logTextView.frame), 30, 30);
    clearLogBtn.backgroundColor = [UIColor clearColor];
    [clearLogBtn setTitle:@"X" forState:UIControlStateNormal];
    [clearLogBtn setTitleColor:PSRGBS(100) forState:UIControlStateNormal];
    clearLogBtn.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    [clearLogBtn addTarget:self action:@selector(clearLogViewAction:) forControlEvents:UIControlEventTouchUpInside];
    clearLogBtn.layer.borderColor = [UIColor colorWithWhite:0.8f alpha:0.8f].CGColor;
    clearLogBtn.layer.borderWidth = 0.5f;
    [self.view addSubview:clearLogBtn];
    
    
    
    //push按钮
    self.pushBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    _pushBtn.frame = CGRectMake(0, [UIScreen mainScreen].bounds.size.height-64-50, [UIScreen mainScreen].bounds.size.width, 50);
    _pushBtn.backgroundColor = PSRGBS(150);
    [_pushBtn setTitle:@"PUSH" forState:UIControlStateNormal];
    [_pushBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _pushBtn.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [_pushBtn addTarget:self action:@selector(pushAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_pushBtn];
    
    
    
    
    //收起键盘滑动条
    UIView *slipView = [[UIView alloc] initWithFrame:CGRectMake(CGRectGetMaxX(_payloadTextView.frame), CGRectGetMaxY(_connectBtn.frame), 25, CGRectGetHeight(_payloadTextView.frame)+15)];
    slipView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:slipView];
    
    UILabel *vL = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(slipView.frame), CGRectGetHeight(slipView.frame))];
    vL.text = @"v\nv\nv\n\n\nv\nv\nv\n\n\nv\nv\nv";
    vL.textColor = PSRGBS(150);
    vL.numberOfLines = 0;
    vL.textAlignment = NSTextAlignmentCenter;
    vL.font = [UIFont systemFontOfSize:15.0];
    vL.backgroundColor = [UIColor clearColor];
    vL.userInteractionEnabled = NO;
    [slipView addSubview:vL];
    
    UISwipeGestureRecognizer *swipeGesture = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeGesture:)];
    swipeGesture.direction = UISwipeGestureRecognizerDirectionDown;
    [slipView addGestureRecognizer:swipeGesture];
    
    
    
}

- (void)dealloc
{
    //在dealloc里边注销监听器
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NOTIFICATION_RDPUSHTOOL_REPORT object:nil];
}






#pragma mark -
#pragma mark - 对外方法
+ (void)saveAppDeviceToken:(NSString *)deviceToken
{
    if(!deviceToken || [deviceToken isEqualToString:@""]) return;
    
    [[NSUserDefaults standardUserDefaults] setObject:deviceToken forKey:savekey_localapp_devicetoken];
    [[NSUserDefaults standardUserDefaults] synchronize];
}





#pragma mark -
#pragma mark - action操作方法
- (void)connectAction:(id)sender
{
    [[RDPushTool sharedTool] connect:^(PTConnectReport *report) {
        
//        NSString *stateStr = @"";
//        
//        if(report.status == PTConnectReportStatusConnecting)
//        {
//            _connectBtn.enabled = NO;
//            stateStr = [NSString stringWithFormat:@"Connecting to APNs... : %@", report.summary];
//        }
//        else if(report.status == PTConnectReportStatusConnectSuccess)
//        {
//            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
//            
//            stateStr = [NSString stringWithFormat:@"APNs Connected: %@", report.summary];
//            [self showDiscConnectBtn:YES];
//        }
//        else if(report.status == PTConnectReportStatusConnectFailure)
//        {
//            stateStr = [NSString stringWithFormat:@"Connect failure...: %@, Press to reconnect.", report.summary];
//            [self showDiscConnectBtn:NO];
//        }
//        
//        [_connectBtn setTitle:stateStr forState:UIControlStateNormal];
        
        [self changeConnectBtnStateForStatus:report.status andSummary:report.summary];
        
    }];
}

- (void)disConnectAction:(id)sender
{
    [[RDPushTool sharedTool] disconnect];
    [_connectBtn setTitle:@"Connect to APNs." forState:UIControlStateNormal];
    [self showDiscConnectBtn:NO];

}

- (void)pushAction:(id)sender
{
    [self addLogToLogView:@"-----------------------------"];
    
    NSString *deviceToken = _tokenField.text;
    NSDictionary *payloadDic = [self getPayloadDic];
    
    [[RDPushTool sharedTool] pushPayload:payloadDic toToken:deviceToken completion:^(PTPushReport *report) {
        
        if(report.status == PTPushReportStatusPushSuccess)
        {
            //推送成功以后，才把payload存起来
            NSString *payload = _payloadTextView.text;
            if(payload && ![payload isEqualToString:@""])
            {
                [[NSUserDefaults standardUserDefaults] setObject:payload forKey:savekey_payload_customize];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
            
            //推送成功以后，才把token存起来
            NSString *token = _tokenField.text;
            if(token && ![token isEqualToString:@""])
            {
                [[NSUserDefaults standardUserDefaults] setObject:token forKey:savekey_devicetoken_customize];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
            
            //TO DO: 处理推送成功
            
        }
    }];
}



- (void)changeConnectBtnStateForStatus:(PTConnectReportStatus)status andSummary:(NSString *)summary
{
    NSString *stateStr = @"";
    
    if(status == PTConnectReportStatusConnecting)
    {
        _connectBtn.enabled = NO;
        stateStr = [NSString stringWithFormat:@"Connecting to APNs... : %@", summary];
    }
    else if(status == PTConnectReportStatusConnectSuccess)
    {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
        
        stateStr = [NSString stringWithFormat:@"APNs Connected: %@", summary];
        [self showDiscConnectBtn:YES];
    }
    else if(status == PTConnectReportStatusConnectFailure)
    {
        stateStr = [NSString stringWithFormat:@"Connect failure...: %@, Press to reconnect.", summary];
        [self showDiscConnectBtn:NO];
    }
    
    [_connectBtn setTitle:stateStr forState:UIControlStateNormal];
}

- (void)showDiscConnectBtn:(BOOL)bshow
{
    if(bshow)
    {
        _connectBtn.enabled = NO;
        _connectBtn.backgroundColor = PSRGBS(170);
        [UIView animateWithDuration:0.25 animations:^{
            _connectBtn.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width-70, 35);
            _disConnectBtn.frame = CGRectMake([UIScreen mainScreen].bounds.size.width-70, 0, 70, 35);
        }];
    }
    else
    {
        _connectBtn.enabled = YES;
        _connectBtn.backgroundColor = PSRGBS(130);
        [UIView animateWithDuration:0.25 animations:^{
            _connectBtn.frame = CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 35);
            _disConnectBtn.frame = CGRectMake([UIScreen mainScreen].bounds.size.width, 0, 70, 35);
        }];
    }
}

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    if(textView != _payloadTextView) return;
    [UIView animateWithDuration:0.25 animations:^{
        _recoverPayloadBtn.alpha = 1.0;
    }];
}
- (void)textViewDidEndEditing:(UITextView *)textView
{
    if(textView != _payloadTextView) return;
    [UIView animateWithDuration:0.25 animations:^{
        _recoverPayloadBtn.alpha = 0.0;
    }];
}

- (void)recoverPayloadAction:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setObject:nil forKey:savekey_payload_customize];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    _payloadTextView.text = [self getUseablePayload];
}


- (void)pasteTokenAction:(id)sender
{
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    _tokenField.text = pasteboard.string;
}

- (void)recoverTokenAction:(id)sender
{
    [[NSUserDefaults standardUserDefaults] setObject:nil forKey:savekey_devicetoken_customize];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    _tokenField.text = [self getUseableDeviceToken];
}

- (void)handleSwipeGesture:(id)sender
{
    if([_payloadTextView isFirstResponder])
    {
        [_payloadTextView resignFirstResponder];
    }
}

- (void)clearLogViewAction:(id)sender
{
    self.logString = @"";
    _logTextView.text = _logString;
        
    //滚动到最顶
    [_logTextView setContentOffset:CGPointMake(0, 0) animated:NO];
}





#pragma mark -
#pragma mark - 一些配套方法
- (void)addLineBelow:(UIView *)viewObj
{
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(viewObj.frame), [UIScreen mainScreen].bounds.size.width, 0.5)];
    line.backgroundColor = PSRGBS(220);
    [self.view addSubview:line];
}
- (NSDictionary *)getPayloadDic
{
    NSString *payloadStr = _payloadTextView.text;
    if(!payloadStr || [payloadStr isEqualToString:@""]) return nil;
    
    payloadStr = [payloadStr stringByReplacingOccurrencesOfString:@" " withString:@""];
    payloadStr = [payloadStr stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    payloadStr = [payloadStr stringByReplacingOccurrencesOfString:@"\t" withString:@""];
    payloadStr = [payloadStr stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    
    NSData *jsonData = [payloadStr dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:nil];
    
    return dic;
}

- (NSString *)getUseablePayload
{
    NSString *payload = [[NSUserDefaults standardUserDefaults] objectForKey:savekey_payload_customize];
    if(payload && ![payload isEqualToString:@""])
    {
        return payload;
    }
    
    NSString *defaultPayload = @"{\n\t\"aps\":\n\t{\n\t\t\"alert\":\n\t\t{\n\t\t\t\"title\":\"我是原装标题\",\n\t\t\t\"subtitle\":\"我是副标题\",\n\t\t\t\"body\":\"it is a beautiful day\"\n\t\t},\n\t\t\"badge\":1,\n\t\t\"sound\":\"default\",\n\t\t\"mutable-content\":\"1\",\n\t\t\"category\":\"myNotificationCategory\",\n\t\t\"attach\":\"http://img3x2.ddimg.cn/29/14/1128514592-1_h_6.jpg\"\n\t},\n\t\"goto_page\":\"link://page=14374\"\n}";
    return defaultPayload;
}

- (NSString *)getUseableDeviceToken
{
    //取用户指定的
    NSString *deviceToken = nil;
    
    deviceToken = [[NSUserDefaults standardUserDefaults] objectForKey:savekey_devicetoken_customize];
    if(deviceToken && ![deviceToken isEqualToString:@""])
    {
        return deviceToken;
    }
    
    //取本机app的
    deviceToken = [[NSUserDefaults standardUserDefaults] objectForKey:savekey_localapp_devicetoken];
    if(deviceToken && ![deviceToken isEqualToString:@""])
    {
        return deviceToken;
    }
    
    return deviceToken;
}




#pragma mark -
#pragma mark NOTIFICATION_RDPUSHTOOL_REPORT消息监听获取当前连接及推送状态的log
- (void)receiveConnectStateNotify:(NSNotification*)notification
{
    if(!notification) return;
    
    NSDictionary *report = (NSDictionary*)notification.object;
    if(!report) return;

    //根据report的内容
    NSString *status = [report objectForKey:@"status"];
    NSString *summary = [report objectForKey:@"summary"];
    
    //处理一下连接按钮显示状态
    if([status isEqualToString:RDPushTool_report_status_connecting] ||
       [status isEqualToString:RDPushTool_report_status_Connectsuccess]||
       [status isEqualToString:RDPushTool_report_status_Connectfailure])
    {
        PTConnectReportStatus connectStatus = PTConnectReportStatusConnecting;
        if([status isEqualToString:RDPushTool_report_status_connecting])
        {
            connectStatus = PTConnectReportStatusConnecting;
        }
        else if([status isEqualToString:RDPushTool_report_status_Connectsuccess])
        {
            connectStatus = PTConnectReportStatusConnectSuccess;
        }
        else if([status isEqualToString:RDPushTool_report_status_Connectfailure])
        {
            connectStatus = PTConnectReportStatusConnectFailure;
        }
        
        [self changeConnectBtnStateForStatus:connectStatus andSummary:summary];
    }
    
    //修改界面显示内容log
    NSString *log = [NSString stringWithFormat:@"%@... ", status];
    if(summary)
    {
        log = [log stringByAppendingFormat:@":%@", summary];
    }
    
    [self addLogToLogView:log];
}

- (void)addLogToLogView:(NSString*)log
{
    if(!log) return;
    
    NSString *time = [self stringFromDate:[NSDate date] useFormat:@"hh:mm:ss"];
    self.logString = [_logString stringByAppendingFormat:@"\n%@ > %@", time, log];
    
    _logTextView.text = _logString;
    
    //滚动到最下面
    CGSize size = _logTextView.contentSize;
    float y = size.height - _logTextView.frame.size.height;
    if(y < 0) y =0;
    
    [_logTextView setContentOffset:CGPointMake(0, y) animated:YES];
}

- (NSString*)stringFromDate:(NSDate*)date useFormat:(NSString*)format
{
    //转化为要显示的时间格式如：@"YY-MM-dd HH:mm:ss"
    if(!date) return nil;
    if(!format || [format isEqualToString:@""]) return nil;
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setTimeZone:[NSTimeZone defaultTimeZone]];
    [formatter setDateFormat:format];
    
    NSString *dateString = [formatter stringFromDate:date];
    
    return dateString;
}



@end
