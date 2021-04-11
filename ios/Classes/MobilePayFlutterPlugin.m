#import "MobilePayFlutterPlugin.h"
#import "MobilePayManager.h"

@implementation MobilePayFlutterPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"mobile_pay_flutter"
                                     binaryMessenger:[registrar messenger]];
    MobilePayFlutterPlugin* instance = [[MobilePayFlutterPlugin alloc] init];
    [instance setChannel:channel];
    [registrar addMethodCallDelegate:instance channel: channel];
    [registrar addApplicationDelegate:instance];
}

- (void) setChannel:(FlutterMethodChannel*)channelToSet {
    channel = channelToSet;
}

- (MobilePayCountry)getCountry:(NSString*)country {
    if([@"fi" isEqualToString:country]) return MobilePayCountry_Finland;
    if([@"no" isEqualToString:country]) return MobilePayCountry_Norway;
    if([@"dk" isEqualToString:country]) return MobilePayCountry_Denmark;
    return MobilePayCountry_Denmark;
}

- (void)sendError:(NSError * __nonnull)error forOrder:(NSString *)orderId {
    [self->channel invokeMethod:@"mobilePayFailure"
                      arguments:
     @{@"orderId":orderId,
       @"errorCode": @(error.code),
       @"errorMessage": [NSString stringWithFormat:@"%@: %@",error.localizedFailureReason, error.localizedDescription],
       @"errorRecoverySuggestion": error.localizedRecoverySuggestion
     }];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"initMobilePay" isEqualToString:call.method]) {
        NSString *merchantId = call.arguments[@"merchantId"];
        NSString *merchantUrl = call.arguments[@"merchantUrlScheme"];
        NSString *country = call.arguments[@"country"];
        [[MobilePayManager sharedInstance] setupWithMerchantId:merchantId merchantUrlScheme:merchantUrl country:[self getCountry:country]];
        result(nil);
    } else if([@"setRequestCode" isEqualToString:call.method]) {
        result(nil);
    } else if([@"createPayment" isEqualToString:call.method]) {
        NSNumber *price = call.arguments[@"productPrice"];
        NSString *orderId = call.arguments[@"orderId"];
        MobilePayPayment *payment = [[MobilePayPayment alloc]initWithOrderId:orderId productPrice:[price floatValue]];
        if (payment && (payment.orderId.length > 0) && (payment.productPrice >= 0)) {
            
            [[MobilePayManager sharedInstance] beginMobilePaymentWithPayment:payment error:^(NSError * __nonnull error) {
                [self sendError:error forOrder:orderId];
            }];
        }
        result(nil);
    } else if([@"downloadMobilePay" isEqualToString:call.method]) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString: @"https://apps.apple.com/fi/app/mobilepay/id768172577"]];
        result(nil);
    } else if([@"isMobilePayInstalled" isEqualToString:call.method]) {
        result(@(
               [[MobilePayManager sharedInstance] isMobilePayInstalled:[MobilePayManager sharedInstance].country]));
    } else {
        result(FlutterMethodNotImplemented);
    }
}

-(BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<NSString *,id> *)options
{
    //IMPORTANT - YOU MUST USE THIS IF YOU COMPILING YOUR AGAINST IOS9 SDK
    [self handleMobilePayPaymentWithUrl:url];
    return YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    //IMPORTANT - THIS IS DEPRECATED IN IOS9 - USE 'application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<NSString *,id> *)options' INSTEAD
    [self handleMobilePayPaymentWithUrl:url];
    return YES;
}

-(BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    
    //IMPORTANT - THIS IS DEPRECATED IN IOS9 - USE 'application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<NSString *,id> *)options' INSTEAD
    [self handleMobilePayPaymentWithUrl:url];
    return YES;
}

- (void)handleMobilePayPaymentWithUrl:(NSURL *)url
{
    [[MobilePayManager sharedInstance]handleMobilePayPaymentWithUrl:url success:^(MobilePaySuccessfulPayment * _Nullable mobilePaySuccessfulPayment) {
        NSString *orderId = mobilePaySuccessfulPayment.orderId;
        NSString *transactionId = mobilePaySuccessfulPayment.transactionId;
        float amountWithdrawnFromCard = mobilePaySuccessfulPayment.amountWithdrawnFromCard;
        
        [self->channel invokeMethod:@"mobilePaySuccess"
                          arguments:
         @{@"orderId": orderId,
           @"transactionId": transactionId,
           @"amountWithdrawnFromCard": @(amountWithdrawnFromCard)
         }];
        
    } error:^(NSError * __nullable error) {
        [self sendError:error forOrder:@""];
    } cancel:^(MobilePayCancelledPayment * _Nullable mobilePayCancelledPayment) {
        [self->channel invokeMethod:@"mobilePayCancel"
                          arguments:
         @{@"orderId": mobilePayCancelledPayment.orderId}];
    }];
}

@end
