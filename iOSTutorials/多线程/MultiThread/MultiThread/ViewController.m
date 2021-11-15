//
//  ViewController.m
//  MultiThread
//
//  Created by minger on 2021/11/15.
//

#import "ViewController.h"
#import "KeepThread.h"
#import "ThreadKeepLiveTestViewController.h"
#import "GCDTestViewController.h"

@interface ViewController ()<UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *datas;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.title = @"多线程";
    self.navigationController.navigationBar.backgroundColor = [UIColor brownColor];
    self.view.backgroundColor = [UIColor whiteColor];
    NSArray *tempDatas = @[@"Thread 线程报活",@"dispatch_queue_t",@"NSOperation"];
    self.datas = [NSMutableArray arrayWithArray:tempDatas];
    
    self.tableView = [[UITableView alloc]initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.width) style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
    

}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return  self.datas.count;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    cell.textLabel.text = self.datas[indexPath.row];
    cell.textLabel.textColor = [UIColor blackColor];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 0) {
        [self.navigationController pushViewController:[ThreadKeepLiveTestViewController new] animated:YES];
    } else if (indexPath.row == 1){
        [self.navigationController pushViewController:[GCDTestViewController new] animated:YES];
    }
}



@end
