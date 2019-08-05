//
//  ESCOpenGLESView.m
//  ESCOpenGLESShowImageDemo
//
//  Created by xiang on 2018/7/25.
//  Copyright © 2018年 xiang. All rights reserved.
//

#import "ESCOpenGLESView.h"
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

@interface ESCOpenGLESView ()

@property(nonatomic,strong)EAGLContext* context;

@property(nonatomic,assign)GLuint frameBuffer;

@property(nonatomic,assign)GLuint renderBuffer;

@property(nonatomic,assign)NSInteger viewWidth;

@property(nonatomic,assign)NSInteger viewHeight;

//================================================================rgb
@property(nonatomic,assign)GLuint texture;

@property(nonatomic,assign)GLuint mGLProgId;

@property(nonatomic,assign)GLuint mGLTextureCoords;

@property(nonatomic,assign)GLuint mGLPosition;

@property(nonatomic,assign)GLuint mGLUniformTexture;

//================================================================

@property(nonatomic,strong)dispatch_queue_t openglesQueue;

//================================================================yuv

@property(nonatomic,assign)GLuint ytexture;

@property(nonatomic,assign)GLuint utexture;

@property(nonatomic,assign)GLuint vtexture;


@property(nonatomic,assign)GLuint mYUVGLProgId;

@property(nonatomic,assign)GLuint mYUVGLTextureCoords;

@property(nonatomic,assign)GLuint mYUVGLPosition;

@property(nonatomic,assign)GLuint s_texture_y;

@property(nonatomic,assign)GLuint s_texture_u;

@property(nonatomic,assign)GLuint s_texture_v;

//================================================================


@end

@implementation ESCOpenGLESView

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupOPENGLES];
    }
    return self;
}

- (void)dealloc {
    NSLog(@"%@====%s",self,__FUNCTION__);
    
    [self destroy];
}

- (void)destroy {
    if(self.context) {
        [EAGLContext setCurrentContext:nil];
    }
    if (self.mYUVGLProgId) {
        glDeleteProgram(self.mYUVGLProgId);
    }
    if (self.mGLProgId) {
        glDeleteProgram(self.mGLProgId);
    }
    if (_frameBuffer) {
        glDeleteFramebuffers(1, &_frameBuffer);
    }
    if (_renderBuffer) {
        glDeleteRenderbuffers(1, &_renderBuffer);
    }
    if (_texture) {
        glDeleteTextures(1, &_texture);
    }
    if (_ytexture) {
        glDeleteTextures(1, &_ytexture);
    }
    if (_utexture) {
        glDeleteTextures(1, &_utexture);
    }
    if (_vtexture) {
        glDeleteTextures(1, &_vtexture);
    }
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    NSInteger width = self.frame.size.width;
    NSInteger height = self.frame.size.height;
    dispatch_sync(self.openglesQueue, ^{
        if (self.viewHeight != height || self.viewWidth != width) {
            //创建缓冲区buffer
            [self setupBuffers];
        }
    });
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self setupOPENGLES];
}

- (void)setupOPENGLES {
    self.openglesQueue = dispatch_queue_create("openglesqueue", DISPATCH_QUEUE_SERIAL);
    //设置layer属性
    CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
    NSDictionary *dict = @{kEAGLDrawablePropertyRetainedBacking:@(NO),
                           kEAGLDrawablePropertyColorFormat:kEAGLColorFormatRGBA8
                           };

    [eaglLayer setDrawableProperties:dict];
    
    [eaglLayer setOpaque:YES];
    
    [eaglLayer setContentsScale:[[UIScreen mainScreen] scale]];
    //创建上下文
    [self setupContext];
    
}

- (void)setupContext {
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    if (self.context == nil) {
        NSLog(@"create context failed!");
        return;
    }
    BOOL result = [EAGLContext setCurrentContext:self.context];
    if (result == NO) {
        NSLog(@"set context failed!");
    }
}

- (void)setupBuffers {
    //检测缓存区
    if (_frameBuffer) {
        glDeleteFramebuffers(1, &_frameBuffer);
    }
    if (_renderBuffer) {
        glDeleteRenderbuffers(1, &_renderBuffer);
    }
    [EAGLContext setCurrentContext:self.context];
    //创建帧缓冲区
    glGenFramebuffers(1, &_frameBuffer);
    //绑定缓冲区
    glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
    
    //创建绘制缓冲区
    glGenRenderbuffers(1, &_renderBuffer);
    //绑定缓冲区
    glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
    
    //为绘制缓冲区分配内存
    [self.context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer];
    
    //获取绘制缓冲区像素高度/宽度
    GLint width;
    GLint height;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &width);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &height);
    NSLog(@"%d==%d",width,height);
    self.viewWidth = width;
    self.viewHeight = height;
    //将绘制缓冲区绑定到帧缓冲区
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderBuffer);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    //检查状态
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (status != GL_FRAMEBUFFER_COMPLETE) {
        NSLog(@"failed to make complete frame buffer object!");
        return;
    }
    GLenum glError = glGetError();
    if (GL_NO_ERROR != glError) {
        NSLog(@"failed to setup GL %x", glError);
    }
}

#pragma mark - 编译RGB_GPU程序
- (void)setupRGBGPUProgram {
    //编译顶点着色器、纹理着色器
    GLuint vertexShader = [self compileShader:@"vertexshader_RGB.vtsd" withType:GL_VERTEX_SHADER];
    GLuint fragmentShader = [self compileShader:@"fragmentshader_RGB.fmsd" withType:GL_FRAGMENT_SHADER];
    
    GLuint programHandle = glCreateProgram();
    glAttachShader(programHandle, vertexShader);
    glAttachShader(programHandle, fragmentShader);
    glLinkProgram(programHandle);
    
    GLint linkSuccess;
    glGetProgramiv(programHandle, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar message[256];
        glGetProgramInfoLog(programHandle, sizeof(message), 0, &message[0]);
        NSString *messageStr = [NSString stringWithUTF8String:message];
        NSLog(@"%@", messageStr);
        return;
    }
    
    glUseProgram(programHandle);
    self.mGLProgId = programHandle;
    _mGLPosition = glGetAttribLocation(programHandle, "position");
    glEnableVertexAttribArray(_mGLPosition);
    
    _mGLTextureCoords = glGetAttribLocation(programHandle, "texcoord");
    glEnableVertexAttribArray(_mGLTextureCoords);
    
    _mGLUniformTexture = glGetUniformLocation(programHandle, "texSampler");
    
}

#pragma mark - 编译YUV_GPU程序
- (void)setupYUVGPUProgram {
    //编译顶点着色器、纹理着色器
    GLuint vertexShader = [self compileShader:@"vertexshader_YUV.vtsd" withType:GL_VERTEX_SHADER];
    GLuint fragmentShader = [self compileShader:@"fragmentshader_YUV.fmsd" withType:GL_FRAGMENT_SHADER];
    //绑定链接程序
    GLuint programHandle = glCreateProgram();
    glAttachShader(programHandle, vertexShader);
    glAttachShader(programHandle, fragmentShader);
    glLinkProgram(programHandle);
    
    GLint linkSuccess;
    glGetProgramiv(programHandle, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar message[256];
        glGetProgramInfoLog(programHandle, sizeof(message), 0, &message[0]);
        NSString *messageStr = [NSString stringWithUTF8String:message];
        NSLog(@"%@", messageStr);
        return;
    }
    //使用程序
    glUseProgram(programHandle);
    self.mYUVGLProgId = programHandle;
    //绑定变量
    _mYUVGLPosition = glGetAttribLocation(programHandle, "position");
    glEnableVertexAttribArray(_mYUVGLPosition);
    
    _mYUVGLTextureCoords = glGetAttribLocation(programHandle, "vTexCords");
    glEnableVertexAttribArray(_mYUVGLTextureCoords);
    
    
    _s_texture_y = glGetUniformLocation(programHandle, "s_texture_y");
    _s_texture_u = glGetUniformLocation(programHandle, "s_texture_u");
    _s_texture_v = glGetUniformLocation(programHandle, "s_texture_v");
    
    glUniform1i(_s_texture_y, 0);
    glUniform1i(_s_texture_u, 1);
    glUniform1i(_s_texture_v, 2);

}

- (GLuint)compileShader:(NSString *)shaderName withType:(GLenum)shaderType {
    NSString *shaderPath = [[NSBundle mainBundle] pathForResource:shaderName ofType:nil];
    NSError *error;
    NSString *shaderString = [NSString stringWithContentsOfFile:shaderPath encoding:NSUTF8StringEncoding error:&error];
    if (!shaderString)
    {
        NSLog(@"Error loading shader: %@", error.localizedDescription);
        return 0;
    }
    
    // create ID for shader
    GLuint shaderHandle = glCreateShader(shaderType);
    
    // define shader text
    const char * shaderStringUTF8 = [shaderString UTF8String];
    int shaderStringLength = (int)[shaderString length];
    glShaderSource(shaderHandle, 1, &shaderStringUTF8, &shaderStringLength);
    
    // compile shader
    glCompileShader(shaderHandle);
    
    // verify the compiling
    GLint compileSucess;
    glGetShaderiv(shaderHandle, GL_COMPILE_STATUS, &compileSucess);
    if (compileSucess == GL_FALSE)
    {
        GLchar message[256];
        glGetShaderInfoLog(shaderHandle, sizeof(message), 0, &message[0]);
        NSString *messageStr = [NSString stringWithUTF8String:message];
        NSLog(@"----%@", messageStr);
        return 0;
    }
    
    return shaderHandle;
}

#pragma mark - 创建纹理
- (void)createTexWithRGBAData:(void *)RGBAData width:(int)width height:(int)height {
    //创建纹理
    glGenTextures(1, &_texture);
    //绑定纹理
    glBindTexture(GL_TEXTURE_2D, _texture);
    
    //设置过滤参数
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    
    //设置映射规则
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, RGBAData);
}

- (void)createTexWithRGBData:(void *)RGBData width:(int)width height:(int)height {
    //创建纹理
    glGenTextures(1, &_texture);
    //绑定纹理
    glBindTexture(GL_TEXTURE_2D, _texture);
    
    //设置过滤参数
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    
    //设置映射规则
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, width, height, 0, GL_RGB, GL_UNSIGNED_BYTE, RGBData);
}

- (void)createTexWithYUVDataWithYData:(NSData *)YData uData:(NSData *)uData vData:(NSData *)vData width:(int)width height:(int)height {
    
    void *ydata = (void *)[YData bytes];
    
    //传递纹理对象
    //创建纹理
    glActiveTexture(GL_TEXTURE0);
    glGenTextures(1, &_ytexture);
    //绑定纹理
    glBindTexture(GL_TEXTURE_2D, _ytexture);
    [self createYUVTextureWithData:ydata width:width height:height texture:&_ytexture];
    //纹理过滤函数
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_NEAREST);//放大过滤
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_NEAREST);//缩小过滤
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);//水平方向
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);//垂直方向

    void *udata = (void *)[uData bytes];
    //创建纹理
    glActiveTexture(GL_TEXTURE1);
    glGenTextures(1, &_utexture);
    //绑定纹理
    glBindTexture(GL_TEXTURE_2D, _utexture);
    [self createYUVTextureWithData:udata width:width / 2 height:height / 2 texture:&_utexture];
    //纹理过滤函数
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_NEAREST);//放大过滤
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_NEAREST);//缩小过滤
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);//水平方向
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);//垂直方向
    
    void *vdata = (void *)[vData bytes];
    
    //创建纹理
    glActiveTexture(GL_TEXTURE2);
    glGenTextures(1, &_vtexture);
    //绑定纹理
    glBindTexture(GL_TEXTURE_2D, _vtexture);
    [self createYUVTextureWithData:vdata width:width / 2 height:height / 2 texture:&_vtexture];
    //纹理过滤函数
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_NEAREST);//放大过滤
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_NEAREST);//缩小过滤
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);//水平方向
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);//垂直方向
    if (!_ytexture || !_ytexture || !_vtexture)
    {
        NSLog(@"glGenTextures faild.");
        return;
    }
}

- (void)createYUVTextureWithData:(void *)data  width:(int)width height:(int)height  texture:(GLuint *)texture {
    
    
    //设置过滤参数
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    
    //设置映射规则
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, width , height , 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, data);
    
}

#pragma mark - 通过opengles加载image

- (void)shaderImage:(UIImage *)image {
    BOOL result = [EAGLContext setCurrentContext:self.context];
    if (result == NO) {
        NSLog(@"set context failed!");
    }
    if (self.texture) {
        glDeleteTextures(1, &_texture);
    }
    
    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT);
    
    //获取图片RGBA数据
    void *pixels = NULL;
    [self getImageRGBAData:image data:&pixels];
    [self createTexWithRGBAData:pixels width:image.size.width height:image.size.height];
    free(pixels);

    glViewport(0, 0, (int)self.viewWidth, (int)self.viewHeight);

    //设置物体坐标
    GLfloat vertices[] = {
        -1.0,-1.0,
        1.0,-1.0,
        -1.0,1.0,
        1.0,1.0
    };
    glVertexAttribPointer(_mGLPosition, 2, GL_FLOAT, 0, 0, vertices);
    
    //设置纹理坐标
    GLfloat texCoords2[] = {
        0,1,
        1,1,
        0,0,
        1,0
    };
    glVertexAttribPointer(_mGLTextureCoords, 2, GL_FLOAT, 0, 0, texCoords2);
    
    //传递纹理对象
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _texture);
    glUniform1i(_mGLUniformTexture, 0);
    
    //执行绘制操作
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    [self.context presentRenderbuffer:GL_RENDERBUFFER];
    
    //删除不使用纹理
    glDeleteTextures(1, &_texture);
    //解绑纹理
    glBindTexture(GL_TEXTURE_2D, 0);
    
}
- (void)loadImage:(UIImage *)image {
    dispatch_async(self.openglesQueue, ^{
        [self shaderImage:image];
    });
}

- (void)loadRGBData:(void *)data lenth:(NSInteger)lenth width:(NSInteger)width height:(NSInteger)height {
    dispatch_sync(self.openglesQueue, ^{
        
            BOOL result = [EAGLContext setCurrentContext:self.context];
            if (result == NO) {
                NSLog(@"set context failed!");
            }
            if (self.texture) {
                glDeleteTextures(1, &_texture);
            }
            
            glClearColor(0, 0, 0, 1);
            glClear(GL_COLOR_BUFFER_BIT);
        
            //创建纹理
            [self createTexWithRGBData:data width:(int)width height:(int)height];
            
        //调整画面宽度
        CGFloat x = 0;
        CGFloat y = 0;
        CGFloat w = 0;
        CGFloat h = 0;
        
        //获取控件宽高比，与视频宽高比
        if (self.viewWidth / self.viewHeight * 1.0 > width / height) {
            h = self.viewHeight;
            w = width * h / height;
            x = (self.viewWidth - w) / 2;
            glViewport(x, y, w, h);
        }else {
            w = self.viewWidth;
            h = height * w / width;
            y = (self.viewHeight - h) / 2;
            glViewport(x, y, w, h);
        }
            //设置物体坐标
            GLfloat vertices[] = {
                -1.0,-1.0,
                1.0,-1.0,
                -1.0,1.0,
                1.0,1.0
            };
            glVertexAttribPointer(_mGLPosition, 2, GL_FLOAT, 0, 0, vertices);
            
            //设置纹理坐标
            GLfloat texCoords2[] = {
                0,1,
                1,1,
                0,0,
                1,0
            };
            glVertexAttribPointer(_mGLTextureCoords, 2, GL_FLOAT, 0, 0, texCoords2);
            
            //传递纹理对象
            glActiveTexture(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, _texture);
            glUniform1i(_mGLUniformTexture, 0);
            
            //执行绘制操作
            glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
            
            [self.context presentRenderbuffer:GL_RENDERBUFFER];
            
            //删除不使用纹理
            glDeleteTextures(1, &_texture);
            //解绑纹理
            glBindTexture(GL_TEXTURE_2D, 0);
        
    });
}

- (void)loadYUV420PDataWithYData:(NSData *)yData uData:(NSData *)uData vData:(NSData *)vData width:(NSInteger)width height:(NSInteger)height {
    dispatch_sync(self.openglesQueue, ^{
        
        BOOL result = [EAGLContext setCurrentContext:self.context];
        if (result == NO) {
            NSLog(@"set context failed!");
        }
        if (self.ytexture) {
            glDeleteTextures(1, &_ytexture);
        }
        if (self.utexture) {
            glDeleteTextures(1, &_utexture);
        }
        if (self.vtexture) {
            glDeleteTextures(1, &_vtexture);
        }
        
        glClearColor(0, 0, 0, 1);
        glClear(GL_COLOR_BUFFER_BIT);
        
        //创建纹理
        [self createTexWithYUVDataWithYData:yData uData:uData vData:vData width:(int)width height:(int)height];
        
        //调整画面宽度
        CGFloat x = 0;
        CGFloat y = 0;
        CGFloat w = 0;
        CGFloat h = 0;
        
        if (self.showType == ESCOpenGLESViewShowTypeAspectFit) {
            //获取控件宽高比，与视频宽高比
            if (self.viewWidth / self.viewHeight * 1.0 > width / height) {
                h = self.viewHeight;
                w = width * h / height;
                x = (self.viewWidth - w) / 2;
                glViewport(x, y, w, h);
            }else {
                w = self.viewWidth;
                h = height * w / width;
                y = (self.viewHeight - h) / 2;
                glViewport(x, y, w, h);
            }
        }else {
            glViewport(x, y, self.viewWidth, self.viewHeight);
        }
        

        //设置物体坐标
        GLfloat vertices[] = {
            -1.0,-1.0,
            1.0,-1.0,
            -1.0,1.0,
            1.0,1.0
        };
//        glEnableVertexAttribArray(_mYUVGLPosition);
        glVertexAttribPointer(_mYUVGLPosition, 2, GL_FLOAT, 0, 0, vertices);
        //设置纹理坐标
        GLfloat texCoords2[] = {
            0,1,
            1,1,
            0,0,
            1,0
        };
//        glEnableVertexAttribArray(_mYUVGLTextureCoords);
        glVertexAttribPointer(_mYUVGLTextureCoords, 2, GL_FLOAT, 0, 0, texCoords2);
        //执行绘制操作
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
        
        [self.context presentRenderbuffer:GL_RENDERBUFFER];
        
        //删除不使用纹理
        glDeleteTextures(1, &_ytexture);
        glDeleteTextures(1, &_utexture);
        glDeleteTextures(1, &_vtexture);
        //解绑纹理
        glBindTexture(GL_TEXTURE_2D, 0);
        
    });
}

#pragma mark - 获取图片RGBA数据
- (void)getImageRGBAData:(UIImage *)image data:(void * *)data {
    CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(image.CGImage);
    CGColorSpaceRef colorRef = CGColorSpaceCreateDeviceRGB();
    
    float width = image.size.width;
    float height = image.size.height;
    
    // Get source image data
    uint8_t *imageData = (uint8_t *) malloc(width * height * 4);
    
    CGContextRef imageContext = CGBitmapContextCreate(imageData,
                                                      width, height,
                                                      8, width * 4,
                                                      colorRef, alphaInfo);
    
    CGContextDrawImage(imageContext, CGRectMake(0, 0, width, height), image.CGImage);
    CGContextRelease(imageContext);
    CGColorSpaceRelease(colorRef);
    *data = imageData;
}

- (void)setType:(ESCVideoDataType)type {
    if (type == ESCVideoDataTypeRGBA) {
        
    }else if (type == ESCVideoDataTypeRGB) {
        //设置GPU程序
        //RGB
        [self setupRGBGPUProgram];
    }else if (type == ESCVideoDataTypeYUV420) {
        [self setupYUVGPUProgram];
    }
}

@end
