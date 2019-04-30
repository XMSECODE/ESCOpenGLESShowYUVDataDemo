//
//  ViewController.m
//  ESCOpenGLESShowYUVDataDemo
//
//  Created by xiang on 2019/3/16.
//  Copyright © 2019 xiang. All rights reserved.
//

#import "ViewController.h"
#import "ESCOpenGLESView.h"

@interface ViewController ()

@property(nonatomic,weak)ESCOpenGLESView* openglesView;

@property(nonatomic,strong)NSFileHandle* readFileHandle;

@property(nonatomic,assign)int currentIndex;

@property(nonatomic,weak)NSTimer* readTimer;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    ESCOpenGLESView *openglesView = [[ESCOpenGLESView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:openglesView];
    self.openglesView = openglesView;
    self.openglesView.type = ESCVideoDataTypeYUV420;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    NSString *yuvFile = [[NSBundle mainBundle] pathForResource:@"yuv_1920_1080" ofType:nil];

    [self showYUVDataWithRate:20
                        width:1920
                       height:1080
                     filePath:yuvFile];
}

- (void)showYUVDataWithRate:(int)rate width:(int)width height:(int)height filePath:(NSString *)filePath {
    
    self.readFileHandle = [NSFileHandle fileHandleForReadingAtPath:filePath];
    NSInteger fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil] fileSize];
    
    self.readTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 / rate repeats:YES block:^(NSTimer * _Nonnull timer) {
        
        unsigned long long  l =  [self.readFileHandle offsetInFile];
        if (l >= fileSize) {
            [timer invalidate];
            [self.readFileHandle closeFile];
            return ;
        }
        NSData *yData = [self.readFileHandle readDataOfLength:width * height];
        NSData *uData = [self.readFileHandle readDataOfLength:width * height / 4];
        NSData *vData = [self.readFileHandle readDataOfLength:width * height / 4];
        
        [self.openglesView loadYUV420PDataWithYData:yData uData:uData vData:vData width:width height:height];
    }];
    
}

@end
