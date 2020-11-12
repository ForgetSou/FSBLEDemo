//
//  ViewController.m
//  FSBLEDemo
//
//  Created by forget on 2020/11/12.
//

#import "ViewController.h"
#import "FSBLEService.h"

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [[FSBLEService shared] connectDevice];
    // Do any additional setup after loading the view.
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}


@end
