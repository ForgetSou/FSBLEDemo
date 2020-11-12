# macOS-BLE蓝牙4.0开发

！！！**中心模式** ！！！

`macOS`的BLE程序代码和`iOS`差不多，只需要修改一些UI组件就可以把`iOS`的代码放在`macOS`上使用，下面列举移除不同之处。

## 1 蓝牙状态一直CBManagerStateUnsupported的问题

在`Xcode`中打开targets中的沙盒蓝牙设置，具体路径: TARGETS - Signing & Capanilities - App Sandbox - Handware - Bluetooth

![TARGET-Bluetooth](https://upload-images.jianshu.io/upload_images/16097449-991961ad72610e69.jpg?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240) 

info.plist 里面添加`NSBluetoothPeripheralUsageDescription` Value 根据具体业务详细说明使用蓝牙的目的，以提示用户开启蓝牙权限，避免审核被拒。

## 2 代码实现

### **2.1 导入蓝牙库**

```#import <CoreBluetooth/CoreBluetooth.h>```

### **2.2 添加代理头**

``` 
<
CBCentralManagerDelegate,
CBPeripheralDelegate
>
```

### **2.3 实例化对象**

```
@property (strong, nonatomic) CBCentralManager *manager; // 中心管理器
@property (strong, nonatomic) CBPeripheral *peripheral;	 // 发现的设备
```

### **2.4 初始化管理器，启动蓝牙**

```
self.manager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue()];
// 或者
self.manager = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue() options:@{}];
// 或者
self.manager = [[CBCentralManager alloc] init];
self.manager.delegate = self;
```

### **2.5 查看蓝牙状态并开启扫描**
不实现**centralManagerDidUpdateState**会崩溃

```
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    NSString *tipMsg = @"";
    switch (central.state) {
        case CBManagerStatePoweredOn:
        {
          // 蓝牙打开
            [self.manager scanForPeripheralsWithServices:nil options:nil];
          //[self.manager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:@""]] options:@{CBCentralManagerScanOptionAllowDuplicatesKey : @YES}];
        }
            break;
        case CBManagerStatePoweredOff:
          // 蓝牙关闭<设置关闭，退出前台都会回调>
        		
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
  // 添加alert提示
}
```
### **2.6 扫描并连接设备**

```
#pragma mark - CBCentralManagerDelegate
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *,id> *)advertisementData RSSI:(NSNumber *)RSSI {
    if (peripheral == nil || peripheral.identifier == nil || kStringEmpty(peripheral.identifier.UUIDString)) {
        return;
    }
    if ([peripheral.name isEqualToString:@"Smart voice"]) {
        self.peripheral = peripheral;
        self.peripheral.delegate = self;
        [self.manager stopScan];
        [self.manager connectPeripheral:peripheral options:nil];
    }
}
```
1. `CBConnectPeripheralOptionNotifyOnConnectionKey`

这是一个NSNumber(Boolean)，表示系统会为获得的外设显示一个提示，当成功连接后这个应用被挂起，这对于没有运行在中心后台模式并不显示他们自己的提示时是有用的。如果有更多的外设连接后都会发送通知，如果附近的外设运行在前台则会收到这个提示。

2. `CBConnectPeripheralOptionNotifyOnDisconnectionKey` 

这是一个NSNumber(Boolean), 表示系统会为获得的外设显示一个关闭提示，如果这个时候关闭了连接，这个应用会挂起。

3. `CBConnectPeripheralOptionNotifyOnNotificationKey`

这是一个NSNumber(Boolean)，表示系统会为获得的外设收到通知后显示一个提示，这个时候应用是被挂起的。

### **2.7 连接后的回调**

```
// 连接成功
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    // 发现服务
    [self.peripheral discoverServices:nil];
    // [self.peripheral discoverServices:@[[CBUUID UUIDWithString:@"特定的服务"]]];
}
// 连接失败
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    
}
// 断开连接
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    
}
```
### **2.8 搜索指定服务并查询指定特征<也可以根据特征UUID读取特征值>**

```
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    NSArray *services = peripheral.services;
    if (kArrayEmpty(services)) {
        return;
    }
    for (CBService *service in services) {
        if ([service.UUID.UUIDString containsString:SERVICE_UUID]) {
            [self.peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:CHARACTERISTICS_UUID]] forService:service];
        }
    }
}
```
### **2.9 找出指定的characteristics特征并读取**

```
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    NSArray *characteristics = service.characteristics;
    for (CBCharacteristic *charact in characteristics) {
        if ([charact.UUID.UUIDString containsString:CHARACTERISTICS_UUID]) {
            [self.peripheral setNotifyValue:YES forCharacteristic:charact];
        }
    }
}
```
### **2.10 监控Characteristics新数据并提取**
```
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error {
    NSLog(@"%@   %@", characteristic, characteristic.UUID.UUIDString);
    if (characteristic.value) {
        // 解析特征Value
      
    }
}
```
### **2.11 写数据**
```
[self.peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
// CBCharacteristicWriteWithoutResponse
// CBCharacteristicWriteWithResponse
```
