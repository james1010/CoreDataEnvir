//
//  ConcurrencyViewController.m
//  CoreDataEnvirSample
//
//  Created by Deheng.Xu on 13-9-26.
//  Copyright (c) 2013年 Nicholas.Xu. All rights reserved.
//

#import "ConcurrencyViewController.h"

#import "CoreDataEnvir.h"
#import "Team.h"
#import "Member.h"

#define THREAD_NUMBER  1024
#define LOOP_NUMBER_PER_THREAD  101
#define TESTING_A   1
#define TESTING_B   2
#define TESTING_C   3
#define testing_case TESTING_C

@interface ConcurrencyViewController ()

@end

@implementation ConcurrencyViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        __runs_sema = dispatch_semaphore_create(1l);
    }
    return self;
}

- (void)dealloc
{
    dispatch_release(__runs_sema);
    [super dealloc];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor lightGrayColor];

    NSString * actions[3] = {@"onClick_test:", @"onClick_clearAll:", @"onClick_look:"};
    NSString * titles[3] = {@"Test Concurrency", @"Clear DB", @"Watch"};
    
    CGSize buttonSize = CGSizeMake(180, 60);
    
    for (int i = 0; i < 3; i++) {
        
        UIButton *btn = [[[UIButton alloc] initWithFrame:CGRectZero] autorelease];
        btn.frame = CGRectMake(20, 20 + self.navigationController.navigationBar.frame.size.height + i * buttonSize.height, buttonSize.width, buttonSize.height);
        [btn addTarget:self action:NSSelectorFromString(actions[i]) forControlEvents:UIControlEventTouchUpInside];
        [btn setTitle:titles[i] forState:UIControlStateNormal];
        [self.view addSubview:btn];
        
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

int runs_forever = THREAD_NUMBER;
- (void)updateDatabaseOnMainThread
{
    dispatch_async(dispatch_get_main_queue(), ^{
        CoreDataEnvir *db = [CoreDataEnvir instance];
        short testCounter = 0;
        NSLog(@"Start updating...");
        while (runs_forever && testCounter >= 0) {
            testCounter ++;
            Team *team = [Team lastItemInContext:db usingPredicate:[NSPredicate predicateWithFormat:@"name==%@", @"com.cyblion"]];
            team.number = @(testCounter);
            [db saveDataBase];
            printf("update to \"%hd\".\n", testCounter);
        }
        NSLog(@"Stoped updating.");
    });
    
}

- (void)runTestA:(dispatch_queue_t)queue withTimes:(unsigned int)times
{
    //Every thread runs 101 times Request operation.
    int runTimes = times;
    dispatch_async(queue, ^{
        CoreDataEnvir *db = [CoreDataEnvir instance];

        NSString *queueLabel = [NSString stringWithCString:dispatch_queue_get_label(queue) encoding:NSUTF8StringEncoding];
        
        for (int i = 0; i < runTimes; i++) {
            Team *team = (Team *)[Team lastItemInContext:db usingPredicate:[NSPredicate predicateWithFormat:@"name==%@", queueLabel]];
            
            if (team) {
                NSLog(@"testing queue :%@; team.number :%@", queueLabel, team.number);
            }
        }
        dispatch_semaphore_wait(__runs_sema, ~0ull);
        runs_forever--;
        dispatch_semaphore_signal(__runs_sema);
        NSLog(@"runs_forever :%d", runs_forever);
    });
}

- (void)runTestB:(dispatch_queue_t)queue withTimes:(unsigned int)times
{
    //Every thread runs 101 times CRUD operation.
    int runTimes = times;
    dispatch_async(queue, ^{
        CoreDataEnvir *db = [CoreDataEnvir instance];
        unsigned int c = counter;
        NSString *queueLabel = [NSString stringWithCString:dispatch_queue_get_label(queue) encoding:NSUTF8StringEncoding];
        
        for (int i = 0; i < runTimes; i++) {
            Team *team = (Team *)[Team lastItemInContext:db usingPredicate:[NSPredicate predicateWithFormat:@"name==%@", queueLabel]];
            
            //Delete item.
            if (team) {
                [team removeFrom:db];
                team.number = @(0 + c * 10000);
                NSLog(@"testing queue :%@; team.number :%@", queueLabel, team.number);
            }
            else {
                //Inset item.
                [Team insertItemInContext:db fillData:^(Team *item) {
                    item.name = queueLabel;
                    item.number = @(0 + c * 10000);
                }];
            }
            [db saveDataBase];
        }
        dispatch_semaphore_wait(__runs_sema, ~0ull);
        runs_forever--;
        dispatch_semaphore_signal(__runs_sema);
        NSLog(@"runs_forever :%d", runs_forever);
    });
}

int counter = 0;
- (void)onClick_test:(id)sender
{
    
#if testing_case == TESTING_A
    
    if (runs_forever <= 0) {
        dispatch_semaphore_wait(__runs_sema, ~0ull);
        runs_forever = THREAD_NUMBER;
        dispatch_semaphore_signal(__runs_sema);
        [self updateDatabaseOnMainThread];
    }
    
    for (int i = 0; i < THREAD_NUMBER; i++) {
        dispatch_queue_t q1 = NULL;
        //Start 20 thread for testing, every thread runs CRUD operation 101 times on Name "com.cyblion".
        q1 = dispatch_queue_create([[NSString stringWithFormat:@"com.cyblion"] cStringUsingEncoding:NSUTF8StringEncoding], NULL);
        if (q1) {
            [self runTestA:q1 withTimes:LOOP_NUMBER_PER_THREAD];
        }
        dispatch_release(q1);
    }
    
#elif testing_case == TESTING_B
    
    for (int i = 0; i < THREAD_NUMBER; i++) {
        dispatch_queue_t q1 = NULL;
        
        //Start 'THREAD_NUMBER' thread for testing, every thread runs CRUD operation 'LOOP_NUMBER_PER_THREAD' times seperately.
        q1 = dispatch_queue_create([[NSString stringWithFormat:@"com.cyblion.%d", ++counter] cStringUsingEncoding:NSUTF8StringEncoding], NULL);
        if (q1) {
            [self runTestB:q1 withTimes:LOOP_NUMBER_PER_THREAD];
            dispatch_release(q1);
        }
    }
    
#elif testing_case == TESTING_C
    
    int i = 0;
    
    for (i = 1; i <= 1024; i++) {
//        dispatch_queue_t q = dispatch_queue_create([[NSString stringWithFormat:@"com.cyblion.testing_c.%d", i] cStringUsingEncoding:NSUTF8StringEncoding], NULL);
//        
//        dispatch_async(q, ^{
        NSLog(@"\n\n\n===========================");
        NSLog(@"Instance number [%d]", i);
            CoreDataEnvir *cde = [CoreDataEnvir createInstance];
        
        if (!cde) {
            break;
        }
        
        //Pure manual code.
//            NSManagedObjectContext * context = [[NSManagedObjectContext alloc] init];
//            [context setRetainsRegisteredObjects:NO];
//            [context setPropagatesDeletesAtEndOfEvent:NO];
//            [context setMergePolicy:NSOverwriteMergePolicy];
//
//            NSString *momdPath = [[NSBundle mainBundle] pathForResource:@"SampleModel" ofType:@"momd"];
//            NSURL *momdURL = [NSURL fileURLWithPath:momdPath];
//            NSManagedObjectModel *_m = [[[NSManagedObjectModel alloc] initWithContentsOfURL:momdURL] autorelease];
//            NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:_m];
//        
//            NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
//                                     [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
//                                     [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption,
//                                     nil];
//
//            NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
//
//            [psc addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/db.sqlite", path]] options:options error:nil];
//            [context setPersistentStoreCoordinator:psc];
//            if (!_m) {
//                NSLog(@"Reached number %d", i);
//                break;
//            }
        
//        });
//
//        dispatch_release(q);
        
    }
    
    NSString *message = [NSString stringWithFormat:@"Reaching number %d", i];
    UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"" message:message delegate:Nil cancelButtonTitle:@"Close" otherButtonTitles: nil] autorelease];
    [alert show];

    
#endif
    
    
}

- (void)onClick_clearAll:(id)sender
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        CoreDataEnvir *db = [CoreDataEnvir instance];
        
        NSArray *teams = [Team itemsInContext:db];
        [db deleteDataItems:teams];

        NSArray *members = [Member itemsInContext:db];
        [db deleteDataItems:members];

        [db saveDataBase];
    });
}

- (void)onClick_look:(id)sender
{
    //self.tem.number;
    CoreDataEnvir *db = [CoreDataEnvir instance];
    NSArray *teams = [Team itemsInContext:db];
    NSArray *members = [Member itemsInContext:db];
    
    NSString *message = [NSString stringWithFormat:@"teams :%d\nmembers :%d", [teams count], [members count]];
    UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"" message:message delegate:Nil cancelButtonTitle:@"Close" otherButtonTitles: nil] autorelease];
    [alert show];
}


@end