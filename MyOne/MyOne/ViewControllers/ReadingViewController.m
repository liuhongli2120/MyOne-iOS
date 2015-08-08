//
//  ReadingViewController.m
//  MyOne
//
//  Created by HelloWorld on 7/27/15.
//  Copyright (c) 2015 melody. All rights reserved.
//

#import "ReadingViewController.h"
#import "RightPullToRefreshView.h"
#import <unistd.h>
#import "ReadingEntity.h"
#import <MJExtension/MJExtension.h>
#import "ReadingView.h"
#import "HTTPTool.h"

@interface ReadingViewController () <RightPullToRefreshViewDelegate, RightPullToRefreshViewDataSource>

@property (nonatomic, strong) RightPullToRefreshView *rightPullToRefreshView;

@end

@implementation ReadingViewController {
	// 当前一共有多少篇文章，默认为3篇
	NSInteger numberOfItems;
	// 保存当前查看过的数据
//	NSMutableArray *readItems;
	NSMutableDictionary *readItems;
	// 测试数据
//	ReadingEntity *readingEntity;
	// 最后更新的日期
	NSString *lastUpdateDate;
	// 当前展示的 item 的下标
	NSInteger currentItemIndex;
}

#pragma mark - View Lifecycle

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	
	if (self) {
		UIImage *deselectedImage = [[UIImage imageNamed:@"tabbar_item_reading"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
		UIImage *selectedImage = [[UIImage imageNamed:@"tabbar_item_reading_selected"] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
		// 底部导航item
		UITabBarItem *tabBarItem = [[UITabBarItem alloc] initWithTitle:@"文章" image:nil tag:0];
		tabBarItem.image = deselectedImage;
		tabBarItem.selectedImage = selectedImage;
		self.tabBarItem = tabBarItem;
	}
	
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	// Do any additional setup after loading the view.
	[self setUpNavigationBarShowRightBarButtonItem:YES];
	self.view.backgroundColor = WebViewBGColor;
	
	numberOfItems = 2;
	readItems = [[NSMutableDictionary alloc] init];
	lastUpdateDate = [BaseFunction stringDateBeforeTodaySeveralDays:0];
	currentItemIndex = 0;
	
//	[self loadTestData];
	
	self.rightPullToRefreshView = [[RightPullToRefreshView alloc] initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT - 64 - CGRectGetHeight(self.tabBarController.tabBar.frame))];
	self.rightPullToRefreshView.delegate = self;
	self.rightPullToRefreshView.dataSource = self;
	[self.view addSubview:self.rightPullToRefreshView];
	
	__weak typeof(self) weakSelf = self;
	self.hudWasHidden = ^() {
//		NSLog(@"hudWasHidden");
		[weakSelf whenHUDWasHidden];
	};
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nightModeSwitch:) name:@"DKNightVersionNightFallingNotification" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(nightModeSwitch:) name:@"DKNightVersionDawnComingNotification" object:nil];
	
	[self requestReadingContentAtIndex:0];
}

#pragma mark - Lifecycle

- (void)dealloc {
	self.rightPullToRefreshView.delegate = nil;
	self.rightPullToRefreshView.dataSource = nil;
	self.rightPullToRefreshView = nil;
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

#pragma mark - NSNotification

- (void)nightModeSwitch:(NSNotification *)notification {
//	[self.rightPullToRefreshView reloadItemAtIndex:currentItemIndex animated:NO];
}

#pragma mark - RightPullToRefreshViewDataSource

- (NSInteger)numberOfItemsInRightPullToRefreshView:(RightPullToRefreshView *)rightPullToRefreshView {
//	NSLog(@"Person numberOfItemsInRightPullToRefreshView");
	return numberOfItems;
}

- (UIView *)rightPullToRefreshView:(RightPullToRefreshView *)rightPullToRefreshView viewForItemAtIndex:(NSInteger)index reusingView:(UIView *)view {
	ReadingView *readingView = nil;
	
	//create new view if no view is available for recycling
	if (view == nil) {
		view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(rightPullToRefreshView.frame), CGRectGetHeight(rightPullToRefreshView.frame))];
		readingView = [[ReadingView alloc] initWithFrame:view.bounds];
		[view addSubview:readingView];
	} else {
		readingView = (ReadingView *)view.subviews[0];
	}
	
	//remember to always set any properties of your carousel item
	//views outside of the `if (view == nil) {...}` check otherwise
	//you'll get weird issues with carousel item content appearing
	//in the wrong place in the carousel
	if (index == numberOfItems - 1 || index == readItems.count) {// 当前这个 item 是没有展示过的
//		NSLog(@"reading refresh index = %ld", index);
		[readingView refreshSubviewsForNewItem];
	} else {// 当前这个 item 是展示过了但是没有显示过数据的
//		NSLog(@"reading configure index = %ld", index);
		//		lastConfigureViewForItemIndex = MAX(index, lastConfigureViewForItemIndex);
		[readingView configureReadingViewWithReadingEntity:readItems[[@(index) stringValue]]];
	}
	
	return view;
}

#pragma mark - RightPullToRefreshViewDelegate

- (void)rightPullToRefreshViewRefreshing:(RightPullToRefreshView *)rightPullToRefreshView {
	[self showHUDWaitingWhileExecuting:@selector(request)];
}

- (void)rightPullToRefreshView:(RightPullToRefreshView *)rightPullToRefreshView didDisplayItemAtIndex:(NSInteger)index {
	currentItemIndex = index;
//	NSLog(@"reading didDisplayItemAtIndex index = %ld, numberOfItems = %ld", index, numberOfItems);
	if (index == numberOfItems - 1) {// 如果当前显示的是最后一个，则添加一个 item
//		NSLog(@"reading add new item ----");
		numberOfItems++;
		[self.rightPullToRefreshView insertItemAtIndex:(numberOfItems - 1) animated:YES];
	}
	
	if (index < readItems.count && readItems[[@(index) stringValue]]) {
		//		NSLog(@"question lastConfigureViewForItemIndex = %ld index = %ld", lastConfigureViewForItemIndex, index);
//		NSLog(@"reading didDisplay index = %ld", index);
		ReadingView *readingView = (ReadingView *)[rightPullToRefreshView itemViewAtIndex:index].subviews[0];
		[readingView configureReadingViewWithReadingEntity:readItems[[@(index) stringValue]]];
	} else {
		[self requestReadingContentAtIndex:index];
	}
}

#pragma mark - Network Requests

- (void)request {
	sleep(2);
}

- (void)requestReadingContentAtIndex:(NSInteger)index {
	NSString *date = [BaseFunction stringDateBeforeTodaySeveralDays:index];
	[HTTPTool requestReadingContentByDate:date lastUpdateDate:lastUpdateDate success:^(AFHTTPRequestOperation *operation, id responseObject) {
		if ([responseObject[@"result"] isEqualToString:REQUEST_SUCCESS]) {
//			NSLog(@"reading request index = %ld date = %@ success-------", index, date);
			ReadingEntity *returnReadingEntity = [ReadingEntity objectWithKeyValues:responseObject[@"contentEntity"]];
			[readItems setObject:returnReadingEntity forKey:[@(index) stringValue]];
			[self.rightPullToRefreshView reloadItemAtIndex:index animated:NO];
		}
	} failBlock:^(AFHTTPRequestOperation *operation, NSError *error) {
//		NSLog(@"reading error = %@", error);
	}];
}

#pragma mark - Private

- (void)whenHUDWasHidden {
	[self.rightPullToRefreshView endRefreshing];
}

//- (void)loadTestData {
//	for (int i = 0; i < 5; i++) {
//		NSString *fileName = [NSString stringWithFormat:@"reading_content_%d", i];
//		// 先不做成可变的
//		NSDictionary *testData = [BaseFunction loadTestDatasWithFileName:fileName];
//		ReadingEntity *tempReadingEntity = [ReadingEntity objectWithKeyValues:testData[@"contentEntity"]];
//		[readItems addObject:tempReadingEntity];
//	}
//	
////	NSLog(@"readingEntity = %@", readingEntity);
//}

#pragma mark - Parent

- (void)share {
	[super share];
//	NSLog(@"share --------");
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
