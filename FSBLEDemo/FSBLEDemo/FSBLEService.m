//
//  FSBLEService.m
//
//  Created by forget on 2020/6/30.
//  Copyright © 2020 forget. All rights reserved.
//

#pragma mark - 判空

#define kStringIsEmpty(string)              (string == NULL || [string isKindOfClass:[NSNull class]] || string == nil || [string length] < 1)
#define kArrayIsEmpty(array)                (array == nil || [array isKindOfClass:[NSNull class]] || array.count == 0)
#define kDictionaryIsEmpty(dictionary)      (dictionary == nil || [dictionary isKindOfClass:[NSNull class]] || dictionary.allKeys.count == 0)
#define kObjectIsEmpty(object)              (object == nil||[object isKindOfClass:[NSNull class]]||([object respondsToSelector:@selector(length)] && [(NSData *)object length] == 0)|| ([object respondsToSelector:@selector(count)] && [(NSArray *)object count] == 0))


#import "FSBLEService.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

static NSString *const DEVICE_NAME         = @"Smart voice";
static NSString *const UUID_SERVER         = @"FFF0";
static NSString *const UUID_CHARACTERISTIC = @"FFF6";
static NSString *const UUID_DESCRIPTOR     = @"00002902-0000-1000-8000-00805F9B34FB";

static NSString *const RECORD_START        = @"01";
static NSString *const RECORD_END          = @"02";
static NSString *const TRANSLATE_END       = @"03";

@interface FSBLEService ()<CBPeripheralDelegate, CBCentralManagerDelegate>

@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) CBPeripheral *discoveredPeripheral;
@property (strong, nonatomic) CBCharacteristic *discoveredCharacteristic;
@property (strong, nonatomic) NSTimer *timer;

@end

@implementation FSBLEService

- (id)init {
    self = [super init];
    if (self) {
        [self defaultSetting];
    }
    return self;
}

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    static FSBLEService *instance;
    dispatch_once(&onceToken, ^{
        instance = [[FSBLEService alloc] init];
    });
    return instance;
}

- (void)defaultSetting {
    
}

- (void)reConnectDevice {
    NSArray *pers = [self.centralManager retrieveConnectedPeripheralsWithServices:@[[CBUUID UUIDWithString:UUID_SERVER]]];
    if (!kArrayIsEmpty(pers)) {
        for (CBPeripheral *per in pers) {
            if ([per.name isEqualToString:DEVICE_NAME]) {
                [self.centralManager stopScan];
                self.discoveredPeripheral = per;
                self.discoveredPeripheral.delegate = self;
                if (self.discoveredPeripheral.state == CBPeripheralStateDisconnected) {
                    [self.centralManager connectPeripheral:self.discoveredPeripheral options:nil];
                }
                break;
            }
        }
    }
}

- (void)connectDevice {
    //如果手机蓝牙关闭后重新打开走此处方法
    self.centralManager.delegate = nil;
    self.centralManager = [[CBCentralManager alloc]initWithDelegate:self queue:nil];
}

#pragma mark - CBCentralManagerDelegate
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    NSString *tipMsg = @"";
    switch (central.state) {
        case CBManagerStatePoweredOn:
        {
            [self.centralManager scanForPeripheralsWithServices:nil options:nil];
        }
            break;
        case CBManagerStatePoweredOff:
        {
            [FSBLEService shared].androidId = @"";
            self.timer = [NSTimer timerWithTimeInterval:5 target:self selector:@selector(reConnectDevice) userInfo:nil repeats:YES];
            [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
        }
            break;
        case CBManagerStateUnknown:
            tipMsg = @"手机没有识别到蓝牙，请检查手机。";
            break;
        case CBManagerStateUnauthorized:
            tipMsg = @"手机蓝牙功能没有权限，请前往设置。";
            break;
        case CBManagerStateResetting:
            tipMsg = @"手机蓝牙已断开连接，重置中...";
            break;
        case CBManagerStateUnsupported:
            tipMsg = @"手机不支持蓝牙功能，请更换手机。";
            break;
        default:
            break;
    }
    if (!kStringIsEmpty(tipMsg)) {
        NSLog(@"tipMsg = %@", tipMsg);
        // 添加alert
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    if (peripheral == nil || peripheral.identifier == nil) {
        return;
    }
    NSArray *pers = [self.centralManager retrieveConnectedPeripheralsWithServices:@[[CBUUID UUIDWithString:UUID_SERVER]]];
    if (!kArrayIsEmpty(pers)) {
        for (CBPeripheral *per in pers) {
            if ([per.name isEqualToString:DEVICE_NAME]) {
                [self.centralManager stopScan];
                self.discoveredPeripheral = per;
                self.discoveredPeripheral.delegate = self;
                [self.centralManager connectPeripheral:self.discoveredPeripheral options:nil];
                break;
            }
        }
    } else {
        if ([peripheral.name isEqualToString:DEVICE_NAME]) {
            self.discoveredPeripheral = peripheral;
            self.discoveredPeripheral.delegate = self;
            [self.centralManager connectPeripheral:self.discoveredPeripheral options:nil];
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    [self.timer invalidate];
    self.timer = nil;
    [self.centralManager stopScan];
    self.discoveredPeripheral = peripheral;
    self.discoveredPeripheral.delegate = self;
    [self.discoveredPeripheral discoverServices:@[[CBUUID UUIDWithString:UUID_SERVER]]];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BLEDeviceStatusNotif" object:nil userInfo:@{@"BLEStatus" : @(YES)}];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    [self.centralManager connectPeripheral:peripheral options:nil];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
//    [FSBLEService shared].androidId = @"";
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BLEDeviceMac" object:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BLEDeviceStatusNotif" object:nil userInfo:@{@"BLEStatus" : @(NO)}];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"BLEAuthStatus" object:nil userInfo:@{@"status" : @(NO)}];
    self.timer = [NSTimer timerWithTimeInterval:5 target:self selector:@selector(reConnectDevice) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    for (CBService *service in peripheral.services) {
        [self.discoveredPeripheral discoverCharacteristics:nil forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    for (CBCharacteristic *characteristic in service.characteristics) {
        if ([characteristic.UUID.UUIDString isEqualToString:UUID_CHARACTERISTIC]) {
            [self.discoveredPeripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"%@", error.localizedDescription);
    } else {
        if ([characteristic.UUID.UUIDString isEqualToString:UUID_CHARACTERISTIC]) {
            self.discoveredCharacteristic = characteristic;
            
            NSData *data = characteristic.value;
            NSString *valueStr = [self convertToNSStringWithNSData:data];
            valueStr = [valueStr stringByReplacingOccurrencesOfString:@" " withString:@""];
            if (!kStringIsEmpty(valueStr) && valueStr.length == 16) {
                // 截取命令类型 01启动录音 02 录音结束 03 翻译结束传给BLE
                NSString *lenType = [valueStr substringWithRange:NSMakeRange(0, 2)];
                NSString *cmdType = [valueStr substringWithRange:NSMakeRange(2, 2)];
                if ([lenType isEqualToString:@"08"] && [cmdType isEqualToString:RECORD_START]) {
                    // 启动录音（BLE to Phone）
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"deviceBeginTouch" object:nil];
                    return;
                }
                if ([lenType isEqualToString:@"08"] && [cmdType isEqualToString:RECORD_END]) {
                    // 录音结束（BLE to Phone）
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"deviceEndTouch" object:nil];
                    return;
                }
                if ([lenType isEqualToString:@"08"] && [cmdType isEqualToString:TRANSLATE_END]) {
                    // 翻译结束（Phone to BLE）
                    NSLog(@"翻译结束（Phone to BLE）");
                    return;
                }
                /*! 获取Mac地址并授权设备
                 if (kStringIsEmpty([FSBLEService shared].androidId)) {
                     valueStr = [self getMacStrWith:valueStr];
                     [FSBLEService shared].androidId = valueStr;
                     [[NSNotificationCenter defaultCenter] postNotificationName:@"BLEDeviceMac" object:nil];
                     [[FSNetworking shareInstance] authDevice:^(NSString * _Nonnull token, NSString * _Nonnull error) {
                         if (!kStringIsEmpty(error)) {
                             [[NSNotificationCenter defaultCenter] postNotificationName:@"BLEAuthStatus" object:nil userInfo:@{@"status" : @(NO)}];
                         } else {
                             [[NSNotificationCenter defaultCenter] postNotificationName:@"BLEAuthStatus" object:nil userInfo:@{@"status" : @(YES)}];
                         }
                     }];
                 }
                 */
            }
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Write value for characteristic failed ： %@",error.userInfo);
    } else {
        NSLog(@"Write value for characteristic successfull!! ");
    }
}

- (NSString *)getMacStrWith:(NSString *)value {
    NSString *valueS = [value substringFromIndex:4];
    NSMutableString *mutMac = valueS.mutableCopy;
    NSInteger index = mutMac.length;
    while ((index - 2) > 0) {
        index -= 2;
        [mutMac insertString:@":" atIndex:index];
    }

    NSString *mac = [self getConvertMacWithMac:mutMac];
    return [mac stringByReplacingOccurrencesOfString:@":" withString:@""];
}

- (NSString *)getConvertMacWithMac:(NSString *)mac {
    NSArray *macArr = [mac componentsSeparatedByString:@":"];
    NSArray *newMacArr = [[macArr reverseObjectEnumerator] allObjects];
    return [newMacArr componentsJoinedByString:@":"];
}

- (void)sendToBLE:(NSString *)result {
    if (kStringIsEmpty(result)) {
        return;
    }
    // 1.将文本添加到粘贴板
    
    // 2.发送数据
    unsigned char length = 0x08;
    unsigned char cmdType = 0x03;
    unsigned char key = 0x01;
    unsigned char rsv = 0x1;
    unsigned char version = 0x03;
    unsigned char random1 = 0x8c;
    unsigned char random2 = 0x1d;
    
    unsigned char value = cmdType^key^rsv^version^(random1 + random2);
    unsigned char checksum = NRZI_Encode(value);
    
    unsigned char bytes[8] = {length, cmdType, key, rsv, version, random1, random2, checksum};
    NSData *data = [NSData dataWithBytes:bytes length:8];
    if (self.discoveredPeripheral && self.discoveredCharacteristic) {
        [self.discoveredPeripheral writeValue:data forCharacteristic:self.discoveredCharacteristic type:CBCharacteristicWriteWithoutResponse];
    }
}

- (void)updateBLEDormancyTime:(NSString *)dormancyTime {
    if (kStringIsEmpty(dormancyTime)) {
        return;
    }
    if ([dormancyTime isEqualToString:kDormancyTimeCommon] ||
        ([dormancyTime isEqualToString:kDormancyTimeRecord])) {
        NSData *data = [dormancyTime dataUsingEncoding:NSUTF8StringEncoding];
        if (self.discoveredPeripheral && self.discoveredCharacteristic) {
            [self.discoveredPeripheral writeValue:data forCharacteristic:_discoveredCharacteristic type:CBCharacteristicWriteWithoutResponse];
        }
    }
}

unsigned char NRZI_Encode(unsigned char value) {
    unsigned char i;
    unsigned char result = 0;
    unsigned char last_state= 1;
    for(i=0; i<8; i++) {
        if(value & 0x80) {
            if(last_state){
                result |= (1<<(7-i));
            }
            else{
                result &= ~(1<<(7-i));
            }
        } else {
            if(last_state){
                result &= ~(1<<(7-i));
            } else {
                result |= (1<<(7-i));
            }
        }
        last_state = (result& (1<<(7-i)) ) ? 1 : 0;
        value <<= 1;
    }
    return result;
}

//将data转换为不带<>的字符串
- (NSString *)convertToNSStringWithNSData:(NSData *)data {
    NSMutableString *strTemp = [NSMutableString stringWithCapacity:[data length]*2];
    
    const unsigned char *szBuffer = [data bytes];
    
    for (NSInteger i=0; i < [data length]; ++i) {
        
        [strTemp appendFormat:@"%02lx",(unsigned long)szBuffer[i]];
        
    }
    
    return strTemp;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"BLEDeviceStatusNotif" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"BLEDeviceMac" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"deviceBeginTouch" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"deviceEndTouch" object:nil];
    [self.timer invalidate];
    self.timer = nil;
}

@end
