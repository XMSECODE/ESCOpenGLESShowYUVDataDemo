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
    NSData *yuvData = [NSData dataWithContentsOfFile:yuvFile];
    
    int width = 1920;
    int height = 1080;
    
    uint8_t *yuvDatat = [yuvData bytes];
    NSData *yData = [[NSData alloc] initWithBytes:yuvDatat length:(width *height)];
    NSData *uData = [[NSData alloc] initWithBytes:(yuvDatat + width * height) length:(width * height) / 4];
    NSData *vData = [[NSData alloc] initWithBytes:(yuvDatat + width * height / 4 * 5) length:(width * height) / 4];
    
    
    [self.openglesView loadYUV420PDataWithYData:yData uData:uData vData:vData width:width height:height];
}

@end
