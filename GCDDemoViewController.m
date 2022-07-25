//
//  GCDDemoViewController.m
//  IamGame
//
//  Created by hsec on 2021/9/6.
//  GCD 多核的并行运算 自查 Demo.（包含所有常用 GCD 方法，以及执行逻辑）

/**
 同步函数 串行队列：当前线程，任务串行，会产生阻塞
 同步函数 并发队列：当前线程，任务串行，会产生阻塞
 异步函数 串行队列：开启线程，任务串行
 异步函数 并发队列：开启线程，在当前线程执行任务，任务执行没有顺序，和cpu调度有关
 */

#import "GCDDemoViewController.h"
//#import <PTGXmlParser.h>

@interface bridgeTest:NSObject
@property(nonatomic)id obj;
@end

@implementation bridgeTest : NSObject
-(void)dealloc{
    NSLog(@"———— myObj dealloc ed ————");
}
@end

@interface bridgeTest2:NSObject
@property(nonatomic)id obj;
@end

@implementation bridgeTest2 : NSObject
-(void)dealloc{
    NSLog(@"———— myObj 2 dealloc ed ————");
}
@end

@interface bridgeTest3:NSObject
@property(nonatomic)id obj;
@end

@implementation bridgeTest3 : NSObject
-(void)dealloc{
    NSLog(@"———— myObj 3 dealloc ed ————");
}
@end

@interface GCDDemoViewController (){
    dispatch_source_t myTimerSource;
    dispatch_queue_t timerDebugQueue;
    bool isMyTimering;
}

@end

@implementation GCDDemoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor systemPurpleColor];
    
//    [self taskWithGroup:nil];//队列 组
//    [self deadLockWithSync];//死锁
//    [self barrierTest];//栅栏
//    [self semaphoreTest];//信号量
//    [self dispatchSourceTest];//source
//    [self contextTest];//context
//    [self CF_OC_bridgeDemo];//OC 和 Core fundation 以及 C 转换
//    [self specific_Target_label_test]; //specific 和 Target 和 label 的 -> set get
//    [self otherMethoud];//其他方法「。。。基本定义 block任务 并发迭代 添加优先级。。。」
}

-(UIImage *)taskWithGroup:(NSArray *)dataArr{
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_async(group, queue, ^{
        NSLog(@"「A」实际应用中，AB 顺序 C 顺序 不定");
        dispatch_sync(queue, ^{
            NSLog(@"sleep(10)");
            sleep(10);
            NSLog(@"sleep(10) end");
            dispatch_group_enter(group);//+1
        });
    });
    dispatch_group_async(group, queue, ^{
        dispatch_sync(queue, ^{
            NSLog(@"「B」实际应用中，AB 顺序 C 顺序 不定");
            //          下一行会影响 AB Log 顺序。
            //            sleep(1);
        });
    });
    dispatch_group_async(group, queue, ^{
        dispatch_sync(queue, ^{
            NSLog(@"sleep(6)");
            sleep(6);
            NSLog(@"sleep(6) end");
        });
    });
    sleep(1);
    NSLog(@"「C」实际应用中，AB 顺序 C 顺序 不定");
    dispatch_group_wait(group, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC *20));
    NSLog(@"group wait结束 ");
    
#pragma mark ???:串行队列一定在主线程吗 见:Q001scawce
    /// 对于串行队列，GCD 默认提供了：『主队列（Main Dispatch Queue）』?
    /// 所有放在主队列中的任务，都会放到主线程中执行?
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSLog(@"group notify 收到结束通知");
    });
    
    /**
     * 使用 dispatch_group_async 函数以外的方式从组中显式添加和删除任务，
     * 则使用此函数（与 dispatch_group_leave 一起）允许您的应用程序正确管理任务引用计数。
     *
     * 您可以使用此功能将一个块与多个组同时关联。
     */
    dispatch_group_enter(group);//+1
    dispatch_group_leave(group);//-1
    
    NSLog(@"downloadBigImage return");
    
    return [UIImage imageNamed:@"3"];
}

-(void)deadLockWithSync{//process: 0 __DISPATCH _WAIT_FOR_QUEUE.
    dispatch_queue_t queue2 = dispatch_queue_create("com.hsec.one", DISPATCH_QUEUE_SERIAL);
    NSLog(@"1");
    dispatch_async(queue2, ^{
        NSLog(@"2");
        dispatch_sync(queue2, ^{
            NSLog(@"3");
        });
        NSLog(@"4");
    });
    NSLog(@"5");
    
    dispatch_sync(dispatch_get_main_queue(), ^{
        NSLog(@"if in main thread, dead Lock 2");
    });
}

//栅栏函数只能在当前线程使用，如果多个线程就会出现 意想不到的结果
//栅栏函数也可以在多读单写的场景中使用
-(void)barrierTest{
    dispatch_queue_t queue3 = dispatch_queue_create("com.hsec.one", DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(queue3, ^{
        NSLog(@"1");
    });
    dispatch_async(queue3, ^{
        sleep(5);
        NSLog(@"2");
    });
    dispatch_barrier_sync(queue3, ^{
        NSLog(@"——栅栏——");
    });
    NSLog(@"3");
    dispatch_async(queue3, ^{
        sleep(3);
        NSLog(@"4");
    });
    dispatch_async(queue3, ^{
        NSLog(@"5");
    });
    dispatch_barrier_async(queue3, ^{
        NSLog(@"——螳螂党必——");
    });
    NSLog(@"6");
    dispatch_async(queue3, ^{
        NSLog(@"7");
    });
    NSLog(@"8");
    //error! just test
    dispatch_queue_t globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
    dispatch_async(globalQueue, ^{
        sleep(5);
        NSLog(@"09");
    });
    dispatch_barrier_async(globalQueue, ^{//拦不住:【_HIGH 先log 下一行， _LOW 先Log 12】
        NSLog(@"——栅栏——global");
    });
    dispatch_async(globalQueue, ^{
        sleep(2);
        NSLog(@"10");
    });
    dispatch_barrier_sync(globalQueue, ^{//拦不住
        NSLog(@"——螳螂党必——global");
    });
    dispatch_async(globalQueue, ^{
        NSLog(@"11");
    });
    NSLog(@"12");
    
}

-(void)semaphoreTest{
    dispatch_queue_t globalQueue2 = dispatch_get_global_queue(0, 0);
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(1);
    
    dispatch_async(globalQueue2, ^{
        NSLog(@"1");
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        NSLog(@"1.5");
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        NSLog(@"2");
        dispatch_semaphore_signal(semaphore);//不写会crash，
    });
    dispatch_async(globalQueue2, ^{
        sleep(1);
        NSLog(@"3");
        dispatch_semaphore_signal(semaphore);
        NSLog(@"4");
    });
    NSLog(@"5");
}
#pragma mark - DispatchSource
/**
 它不受Runloop影响，是和Runloop平级的一套Api !!!
 
 DISPATCH_SOURCE_TYPE_DATA_ADD：用于ADD合并数据
 DISPATCH_SOURCE_TYPE_DATA_OR：用于按位或合并数据
 DISPATCH_SOURCE_TYPE_DATA_REPLACE：跟踪通过调用dispatch_source_merge_data获得的数据的分派源，新获得的数据值将替换 尚未交付给源处理程序 的现有数据值
 DISPATCH_SOURCE_TYPE_MACH_SEND：用于监视Mach端口的无效名称通知的调度源，只能发送没有接收权限
 DISPATCH_SOURCE_TYPE_MACH_RECV：用于监视Mach端口的挂起消息
 DISPATCH_SOURCE_TYPE_MEMORYPRESSURE：用于监控系统内存压力变化
 DISPATCH_SOURCE_TYPE_PROC：用于监视外部进程的事件
 DISPATCH_SOURCE_TYPE_READ：监视文件描述符以获取可读取的挂起字节的分派源
 DISPATCH_SOURCE_TYPE_SIGNAL：监控当前进程以获取信号的调度源
 DISPATCH_SOURCE_TYPE_TIMER：基于计时器提交事件处理程序块的分派源
 DISPATCH_SOURCE_TYPE_VNODE：用于监视文件描述符中定义的事件的分派源
 DISPATCH_SOURCE_TYPE_WRITE：监视文件描述符以获取可写入字节的可用缓冲区空间的分派源。
 */
-(void)dispatchSourceTest{
    //DISPATCH_SOURCE_TYPE_TIMER - Test
    [self createTimer:1];
    //Other 待增加
    
}
-(void)createTimer:(NSInteger)period{
    self->myTimerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(0, 0));
    //@pragma leeway 纳秒偏差
    dispatch_source_set_timer(myTimerSource, dispatch_time(DISPATCH_TIME_NOW, 0), period * NSEC_PER_SEC, 0);
    __block int a = 0;
    dispatch_source_set_event_handler(myTimerSource, ^{
        a++;
        NSLog(@"time %d",a);
    });
    
    timerDebugQueue = dispatch_queue_create("me.timer.debug", DISPATCH_QUEUE_SERIAL_INACTIVE);
    [self myTimerDebug];
}
-(void)myTimerDebug{
    //  N * SEC 后 加入队列，而非执行。
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), timerDebugQueue, ^{
        int a = arc4random()%3;
        switch (a) {
            case 0:
                [self runTimeAction];
                [self myTimerDebug];
                break;
            case 1:
                [self pauseTimeAction];
                [self myTimerDebug];
                break;
            case 2://修改频率n arc4random()%n
                arc4random()%6 == 1?[self endTimeAction]:[self myTimerDebug];
                break;
            default:
                break;
        }
    });
    dispatch_activate(timerDebugQueue);
}
//C++ :_dispatch_lane_resume 所以不能多次run
//pause + stop > run 再 run 会crash
-(void)runTimeAction{
    if (myTimerSource&&isMyTimering == NO) {
        isMyTimering = YES;
        dispatch_resume(myTimerSource);
        NSLog(@"start");
    }
}
/**
 暂停之后停止无效。
 同样 myTimerSource = nil 会 crash。
 或者 重新创建source都会造成crash。
 */
-(void)pauseTimeAction{
    if(myTimerSource&&isMyTimering == YES){
        isMyTimering = NO;
        dispatch_suspend(myTimerSource);
        NSLog(@"pause");
    }
}
/**
 取消可防止进一步调用事件处理程序块
 指定的调度源，但不中断事件处理程序已经在进行中的块。取消处理程序被提交到源的目标队列，一旦源的事件处理程序已完成，表明现在可以安全关闭
 */
-(void)endTimeAction{
    if (myTimerSource) {
        [self runTimeAction];//否则 myTimerSource = nil 可能崩溃
        dispatch_source_cancel(myTimerSource);
        isMyTimering = NO;
        myTimerSource = nil;
        timerDebugQueue = nil;
        NSLog(@"Game Over");
    }else{
        NSParameterAssert(myTimerSource);
    }
}

#pragma mark - context
//context在这里可以是任意类型的指针,绑定自定义数据
typedef struct _contextData {
    int number;
} MyData;
//⚠️如果在传context对象时，用的是__bridge转换，那么context对象的内存管理权还在ARC手里，一旦当前作用域执行完，context就会被释放，而如果队列的任务用了context对象，就会造成“EXC_BAD_ACCESS”崩溃！
-(void)contextTest{
    dispatch_queue_t queue5 = dispatch_queue_create("me.context.test", DISPATCH_QUEUE_CONCURRENT);//并行
    //context 并非 'me.context.test'
    MyData *data = malloc(sizeof(MyData));
    data->number = 100;
    dispatch_set_context(queue5, data);
    //set_context 后才生效
    dispatch_set_finalizer_f(queue5, &finalizerXiGou);
    dispatch_async(queue5, ^{
        //一个字节， -128 ~ +127
        char *charStr = dispatch_get_context(queue5);
        MyData *data1 = dispatch_get_context(queue5);
        NSLog(@"charStr:%s \t data1:%d",charStr,data->number);
        data1->number = 200;
    });
}
void finalizerXiGou(void *context){
    NSLog(@"析构A:%p %d",context,((MyData *)context)->number);
    free(context);
    NSLog(@"析构B:%p %d",(MyData *)context,((MyData *)context)->number);
}

#pragma mark !!!:ARC不会管理Core Foundation（CF）Object的生命周期。引用计数demo⬇️
/**
 __bridge :                 OC指针与C互相转换 或 OC对象和Core Foundation转换⚠️不会改变！持有！情况，OC对象出了作用域会被系统自动释放
 __bridge_retained :  OC变量转换为C变量 或 OC对象转换为Core Foundation对象⚠️转换使“转换目标”也持有该对象     CFRelease释放 CFRetain+1
 __bridge_transfer :   C变量转换为OC变量 或 Core Foundation对象转换为OC对象⚠️“被转换的变量”所持有的对象在变量赋值给“转换目标”后释放
 */
-(void)CF_OC_bridgeDemo{
    NSString *imagePath = [[NSBundle mainBundle] pathForResource:@"AppIcon20x20@2x" ofType:@"png"];
    if (imagePath){
        CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge_retained CFURLRef)[NSURL fileURLWithPath:imagePath], NULL);
        CGImageSourceRef source2 = CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:imagePath], NULL);

        NSLog(@"source RetainCount: %ld", CFGetRetainCount(source));
        NSLog(@"source2 RetainCount: %ld", CFGetRetainCount(source2));
        NSLog(@"imagePath RetainCount: %ld", CFGetRetainCount((__bridge CFTypeRef)imagePath));
    }
    
    bridgeTest *obj = [[bridgeTest alloc]init];
    ///p和obj同时持有 obj
    void *p = (__bridge_retained void *)obj;
    NSLog(@"RetainCount: %ld %ld", CFGetRetainCount((CFTypeRef)p), CFGetRetainCount((__bridge CFTypeRef)obj));
    CFRelease((__bridge CFTypeRef)obj);
    NSLog(@"RetainCount: %ld %ld", CFGetRetainCount((CFTypeRef)p), CFGetRetainCount((__bridge CFTypeRef)obj));

    bridgeTest2 *obj2 = [[bridgeTest2 alloc]init];
    ///p2没有持有obj
    void *p2 = (__bridge void *)obj2;
    NSLog(@"RetainCount: %ld %ld", CFGetRetainCount((CFTypeRef)p2), CFGetRetainCount((__bridge CFTypeRef)obj2));

    ///等同于MRC的 obj3 +1, p -1
    bridgeTest3 *obj3 = (__bridge_transfer id)p;
#pragma mark ???:需要retain一次，原因和手动CFRelease 是否有关
    CFBridgingRetain(obj3);
    ///Retain 2次 obj 就会不释放⬇️
//    CFBridgingRetain(obj3);
    NSLog(@"RetainCount: %ld %ld", CFGetRetainCount((CFTypeRef)p), CFGetRetainCount((__bridge CFTypeRef)obj3));
}


#pragma mark TODO:FMDB使用 dispatch_queue_set_specific dispatch_get_specific 来防止死锁
//判断当前队列方法
-(void)specific_Target_label_test{
    dispatch_queue_t s_queue6 = dispatch_queue_create("queue.set_specific.test", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t c_queue7 = dispatch_queue_create("queue.set_target.test", DISPATCH_QUEUE_CONCURRENT);
    const char *mainIdentifier = dispatch_queue_get_label(dispatch_get_main_queue());

    //为指定的调度队列设置密钥/值数据 - const常量，值就不能再被改变
    const void *passKey6 = &passKey6;
    const void *passKey7 = &passKey7;
    //once
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_queue_set_specific(s_queue6, passKey6, &finalizerXiGou, NULL);
        dispatch_queue_set_specific(c_queue7, passKey7, &finalizerXiGou, NULL);
    });
    
    //6任务加入到7。   实际应用场景较复杂，点进去参考官方API方法注释。
    dispatch_set_target_queue(s_queue6, c_queue7);//注释掉 看运行结果
    dispatch_async(s_queue6, ^{
        NSLog(@"————in6 s_queue6 key:%p  s_queue7 key:%p",dispatch_get_specific(passKey6),dispatch_get_specific(passKey7));
        dispatch_get_specific(passKey6) == dispatch_get_specific(passKey7)?NSLog(@"6 Equal 7"):NSLog(@"6 ! Equal 7");
    });
    dispatch_sync(c_queue7, ^{//判断一个代码块是否被这个queue队列执行时可以调用方法
        NSLog(@"————in7 s_queue6 key:%p  s_queue7 key:%p",dispatch_get_specific(passKey6),dispatch_get_specific(passKey7));
        dispatch_get_specific(passKey6) == dispatch_get_specific(passKey7)?NSLog(@"6 Equal 7"):NSLog(@"6 ! Equal 7");
    });
/// 使用dispatch_queue_get_label判断当前队列
    const char *identifier = dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL);
    NSLog(@"strcmp:%d",strcmp(identifier, mainIdentifier)) ;
}

#pragma mark - 未完待续：串行队列的同步任务中，再次向其中派发同步任务会造成死锁

#pragma mark end -
-(void)otherMethoud{
    
    dispatch_queue_t queue;
    dispatch_queue_t queue2;//队列
    dispatch_qos_class_t t;//优先级
    dispatch_queue_attr_t t2;//属性
    dispatch_io_t t3;//读写
    //......

    
//block任务
   dispatch_block_t block = ^{
        NSLog(@"block 任务");
    };
    dispatch_async(queue, block);
    
    
//并发迭代
    dispatch_apply(5, queue, ^(size_t iteration) {
        //串行队列，，串不起来，，不能sleep。。
    });
    
    
//为调度对象object设置qos_class优先级
    if (@available(iOS 12.0, *)) {
        /**
         @param object 要配置的调度队列、工作循环或源。该对象必须处于非活动状态。传递另一个对象类型或已激活的对象是未定义的并将导致进程终止。
         @param qos_class 一个 QOS 等级值：
          - QOS_CLASS_USER_INTERACTIVE
          - QOS_CLASS_USER_INITIATED
          - QOS_CLASS_DEFAULT
          - QOS_CLASS_UTILITY
          - QOS_CLASS_BACKGROUND
         @param relative_priority QOS 类中的相对优先级。此值为负数,与给定类的最大支持调度程序优先级的偏移。
         传递大于零或小于 QOS_MIN_RELATIVE_PRIORITY 的值是未定义的。
         */
        dispatch_set_qos_class_floor(queue, QOS_CLASS_USER_INITIATED, QOS_MIN_RELATIVE_PRIORITY);
    }
    
}

@end


/**
 Q001scawce - 主线程特点：
 如果主线程里有任务就必须等主线程任务执行完才轮到主队列(如果是其他队列的任务，那么任务就不用等待，会直接被主线程执行)的。所以说如果在主队列异步(开启新线程)执行任务无所谓，但是如果在主队列同步(不开启新线程，需要在主线程执行)执行任务会循环等待，造成死锁(但是在一般串行队列这样执行就不会出问题，一切都是因为主线程的这个特点)。
 
 
 dispatch_sync的官方注释里面有这么一句话：
 As an optimization, dispatch_sync() invokes the block on the current thread when possible.
 作为优化，如果可能，直接在当前线程调用这个block。
 所以一般在大多数情况下，通过dispatch_sync添加的任务，在哪个线程添加就会在哪个线程执行。
 上面我们添加的任务的代码是在主线程，所以就直接在主线程执行了。
 在主线程向自定义的串行队列添加的异步任务，会开一个新线程
 在非主线程向自定义的串行队列添加的异步任务，直接在当期线程执行
 
 主线程 主队列 关系
 主队列只在主线程中被执行的，而主线程运行的是一个 runloop，不仅仅只有主队列的中的任务，还会处理 UI 的布局和绘制任务。
 主队列操作UI是安全的，主线程未必！SO （只有一个线程可以操作UI 可以更新为=>只有一个队列可以操作UI）

 */
