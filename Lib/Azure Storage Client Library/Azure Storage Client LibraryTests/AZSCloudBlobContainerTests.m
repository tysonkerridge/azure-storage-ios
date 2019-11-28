// -----------------------------------------------------------------------------------------
// <copyright file="AZSCloudBlobContainerTests.m" company="Microsoft">
//    Copyright 2015 Microsoft Corporation
//
//    Licensed under the MIT License;
//    you may not use this file except in compliance with the License.
//    You may obtain a copy of the License at
//      http://spdx.org/licenses/MIT
//
//    Unless required by applicable law or agreed to in writing, software
//    distributed under the License is distributed on an "AS IS" BASIS,
//    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//    See the License for the specific language governing permissions and
//    limitations under the License.
// </copyright>
// -----------------------------------------------------------------------------------------

#import <XCTest/XCTest.h>
#import "AZSClient.h"
#import "AZSBlobTestBase.h"
#import "AZSConstants.h"
#import "AZSTestHelpers.h"
#import "AZSTestSemaphore.h"
#import "AZSTestHelpers.h"

@interface AZSCloudBlobContainerTests : AZSBlobTestBase

@property NSString *containerName;
@property AZSCloudBlobContainer *blobContainer;

@end

@implementation AZSCloudBlobContainerTests

- (void)setUp
{
    [super setUp];
    self.containerName = [NSString stringWithFormat:@"sampleioscontainer%@", [AZSTestHelpers uniqueName]];
    self.blobContainer = [self.blobClient containerReferenceFromName:self.containerName];
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    [self.blobContainer createContainerIfNotExistsWithCompletionHandler:^(NSError *error, BOOL exists) {
        XCTAssertNil(error, @"Error in test setup, in creating container.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        [semaphore signal];
    }];
    [semaphore wait];
    
    // Put setup code here; it will be run once, before the first test case.
}

- (void)tearDown
{
    // Put teardown code here; it will be run once, after the last test case.
    AZSCloudBlobContainer *blobContainer = [self.blobClient containerReferenceFromName:self.containerName];
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    [blobContainer deleteContainerIfExistsWithCompletionHandler:^(NSError *error, BOOL exists) {
        [semaphore signal];
    }];
    [semaphore wait];
    [super tearDown];
}

- (void)runTestContainerAccessWithAccessType:(AZSContainerPublicAccessType) accessType
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    NSString *containerName = [NSString stringWithFormat:@"sampleioscontainer%@", [AZSTestHelpers uniqueName]];
    NSString *blobName = AZSCBlob;
    NSString *blobText = @"blobText";
    
    AZSCloudBlobContainer *container = [self.blobClient containerReferenceFromName:containerName];
    AZSCloudBlockBlob *blob = [container blockBlobReferenceFromName:blobName];
    
    [container createContainerWithAccessType:accessType requestOptions:nil operationContext:nil completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in creating container.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        [blob uploadFromText:blobText completionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in uploading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            
            AZSCloudBlobContainer *containerPublic = [[AZSCloudBlobContainer alloc] initWithStorageUri:container.storageUri error:&error];
            XCTAssertNil(error);
            
            NSMutableArray *blobs = [[NSMutableArray alloc] initWithCapacity:1];
            [self listAllBlobsFlatInContainer:containerPublic arrayToPopulate:blobs continuationToken:nil prefix:nil blobListingDetails:AZSBlobListingDetailsAll maxResults:1 completionHandler:^(NSError *error) {
                
                if (accessType == AZSContainerPublicAccessTypeContainer)
                {
                    XCTAssertNil(error, @"Error in listing blobs.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                }
                else
                {
                    XCTAssertNotNil(error, @"Did not throw intended error when listing blobs in a blob-level public container.");
                }
                
                NSError *initError;
                AZSCloudBlockBlob *blobPublic = [[AZSCloudBlockBlob alloc] initWithStorageUri:blob.storageUri error:&initError];
                XCTAssertNil(initError);
                
                [blobPublic downloadToTextWithCompletionHandler:^(NSError *error, NSString *resultText) {
                    XCTAssertNil(error, @"Error in downloading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                    XCTAssertTrue([blobText isEqualToString:resultText], @"Text strings do not match.");
                    
                    [container deleteContainerIfExistsWithCompletionHandler:^(NSError *error, BOOL deleted) {
                        [semaphore signal];
                    }];
                }];
            }];
        }];
    }];
    [semaphore wait];
}

-(void)testContainerAccessWithPublicAccess
{
    [self runTestContainerAccessWithAccessType:AZSContainerPublicAccessTypeContainer];
    [self runTestContainerAccessWithAccessType:AZSContainerPublicAccessTypeBlob];
}

-(void)createBlobsForListingTestsWithCompletionHandler:(void (^)(NSArray *, NSString *))completionHandler
{
    NSString *blobText = @"sampleBlobText";
    NSString *blobNamePrefix = [NSString stringWithFormat:@"sampleblob%@", [AZSTestHelpers uniqueName]];
    
    NSMutableArray *blobs = [NSMutableArray arrayWithCapacity:6];
    
    // 11 will have a snapshot, 12 will have metadata, 22 will be a copy of 21, and 23 will be uncommitted.
    AZSCloudBlockBlob *blockBlob11 = [self.blobContainer blockBlobReferenceFromName:[NSString stringWithFormat:@"%@11",blobNamePrefix]];
    AZSCloudBlockBlob *blockBlob12 = [self.blobContainer blockBlobReferenceFromName:[NSString stringWithFormat:@"%@12",blobNamePrefix]];
    AZSCloudBlockBlob *blockBlob21 = [self.blobContainer blockBlobReferenceFromName:[NSString stringWithFormat:@"%@21",blobNamePrefix]];
    AZSCloudBlockBlob *blockBlob22 = [self.blobContainer blockBlobReferenceFromName:[NSString stringWithFormat:@"%@22",blobNamePrefix]];
    AZSCloudBlockBlob *blockBlob23 = [self.blobContainer blockBlobReferenceFromName:[NSString stringWithFormat:@"%@23",blobNamePrefix]];
    
    [blobs addObject:blockBlob11];
    [blobs addObject:blockBlob12];
    [blobs addObject:blockBlob21];
    [blobs addObject:blockBlob22];
    [blobs addObject:blockBlob23];
    
    [blockBlob11 uploadFromText:blobText completionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in uploading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        
        blockBlob12.metadata[@"sampleMetadataKey"] = @"sampleMetadataValue";
        [blockBlob12 uploadFromText:blobText completionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in uploading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        
            [blockBlob21 uploadFromText:blobText completionHandler:^(NSError *error) {
                XCTAssertNil(error, @"Error in uploading blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                
                [blockBlob22 startAsyncCopyFromBlob:blockBlob21 completionHandler:^(NSError *error, NSString *copyId) {
                    XCTAssertNil(error, @"Error in starting async blob copy.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                    
                    [self waitForCopyToCompleteWithBlob:blockBlob22 completionHandler:^(NSError *error, BOOL copySucceeded) {
                        XCTAssertNil(error, @"Error in monitoring blob copy.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                        XCTAssertTrue(copySucceeded, @"Copy operation did not succeed.");
                        
                        [blockBlob23 uploadBlockFromData:[blobText dataUsingEncoding:NSUTF8StringEncoding] blockID:[[@"block" dataUsingEncoding:NSUTF8StringEncoding] base64EncodedStringWithOptions:0] completionHandler:^(NSError *error) {
                            XCTAssertNil(error, @"Error in uploading block.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                            
                            [blockBlob11 snapshotBlobWithMetadata:nil completionHandler:^(NSError *error, AZSCloudBlob *snapshot) {
                                XCTAssertNil(error, @"Error in snapshotting blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                                [blobs addObject:snapshot];
                                completionHandler(blobs, blobNamePrefix);
                            }];
                        }];
                    }];
                }];
            }];
        }];
    }];
}

-(void)listAllBlobsFlatInContainer:(AZSCloudBlobContainer *)container arrayToPopulate:(NSMutableArray *)arrayToPopulate continuationToken:(AZSContinuationToken *)continuationToken prefix:(NSString *)prefix blobListingDetails:(AZSBlobListingDetails)blobListingDetails maxResults:(NSUInteger)maxResults completionHandler:(void (^)(NSError *))completionHandler
{
    [container listBlobsSegmentedWithContinuationToken:continuationToken prefix:prefix useFlatBlobListing:YES blobListingDetails:blobListingDetails maxResults:maxResults completionHandler:^(NSError *error, AZSBlobResultSegment *results) {
        if (error)
        {
            completionHandler(error);
        }
        else
        {
            [arrayToPopulate addObjectsFromArray:results.blobs];
            if (results.continuationToken)
            {
                [self listAllBlobsFlatInContainer:container arrayToPopulate:arrayToPopulate continuationToken:results.continuationToken prefix:prefix blobListingDetails:blobListingDetails maxResults:maxResults completionHandler:completionHandler];
            }
            else
            {
                completionHandler(nil);
            }
        }
    }];
}

-(void)checkBlobPropertiesWithBlob:(AZSCloudBlob *)blob isCommitted:(BOOL)isCommitted isSnapshot:(BOOL)isSnapshot
{
    XCTAssertTrue(blob.properties.blobType == AZSBlobTypeBlockBlob, @"Blob properties not returned correctly.");

    if(isCommitted)
    {
        XCTAssertNotNil(blob.properties.lastModified, @"Blob properties not returned correctly.");
        XCTAssertNotNil(blob.properties.eTag, @"Blob properties not returned correctly.");
        XCTAssertTrue(blob.properties.length.integerValue == 14, @"Blob properties not returned correctly.");
        
        if (!isSnapshot)
        {
            XCTAssertTrue(blob.properties.leaseStatus == AZSLeaseStatusUnlocked, @"Blob properties not returned correctly.");
            XCTAssertTrue(blob.properties.leaseState == AZSLeaseStateAvailable, @"Blob properties not returned correctly.");
        }
    }
}

- (void)testContainerListBlobsSegmentedFlatListingDetailsNone
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    [self createBlobsForListingTestsWithCompletionHandler:^(NSArray *blobs, NSString *blobNamePrefix) {
        NSMutableArray *arrayToPopulate = [NSMutableArray arrayWithCapacity:6];
        [self listAllBlobsFlatInContainer:self.blobContainer arrayToPopulate:arrayToPopulate continuationToken:nil prefix:nil blobListingDetails:AZSBlobListingDetailsNone maxResults:-1 completionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in listing blobs.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            XCTAssertTrue(arrayToPopulate.count == 4, @"Incorrect number of blobs returned.");
            
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[0]).blobName isEqualToString:((AZSCloudBlob *)blobs[0]).blobName], @"Incorrect blob returned.");
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[1]).blobName isEqualToString:((AZSCloudBlob *)blobs[1]).blobName], @"Incorrect blob returned.");
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[2]).blobName isEqualToString:((AZSCloudBlob *)blobs[2]).blobName], @"Incorrect blob returned.");
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[3]).blobName isEqualToString:((AZSCloudBlob *)blobs[3]).blobName], @"Incorrect blob returned.");
            
            for (int i = 0; i < arrayToPopulate.count; i++)
            {
                AZSCloudBlob *blob = (AZSCloudBlob *)arrayToPopulate[i];
                XCTAssertTrue(blob.metadata.count == 0, @"Metadata returned where there should be none.");
                [self checkBlobPropertiesWithBlob:blob isCommitted:YES isSnapshot:NO];
            }
            
            [semaphore signal];
        }];
    }];
    [semaphore wait];
}

- (void)testContainerListBlobsSegmentedFlatWithPrefix
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    [self createBlobsForListingTestsWithCompletionHandler:^(NSArray *blobs, NSString *blobNamePrefix) {
        NSMutableArray *arrayToPopulate = [NSMutableArray arrayWithCapacity:6];
        [self listAllBlobsFlatInContainer:self.blobContainer arrayToPopulate:arrayToPopulate continuationToken:nil prefix:[blobNamePrefix stringByAppendingString:@"1"] blobListingDetails:AZSBlobListingDetailsNone maxResults:-1 completionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in listing blobs.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            XCTAssertTrue(arrayToPopulate.count == 2, @"Incorrect number of blobs returned.");
            
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[0]).blobName isEqualToString:((AZSCloudBlob *)blobs[0]).blobName], @"Incorrect blob returned.");
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[1]).blobName isEqualToString:((AZSCloudBlob *)blobs[1]).blobName], @"Incorrect blob returned.");
            
            for (int i = 0; i < arrayToPopulate.count; i++)
            {
                AZSCloudBlob *blob = (AZSCloudBlob *)arrayToPopulate[i];
                XCTAssertTrue(blob.metadata.count == 0, @"Metadata returned where there should be none.");
                [self checkBlobPropertiesWithBlob:blob isCommitted:YES isSnapshot:NO];
            }

            [semaphore signal];
        }];
    }];
    [semaphore wait];
}

- (void)testContainerListBlobsSegmentedFlatWithMaxResults
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    [self createBlobsForListingTestsWithCompletionHandler:^(NSArray *blobs, NSString *blobNamePrefix) {
        [self.blobContainer listBlobsSegmentedWithContinuationToken:nil prefix:nil useFlatBlobListing:YES blobListingDetails:AZSBlobListingDetailsNone maxResults:3 completionHandler:^(NSError *error, AZSBlobResultSegment *resultSegment) {
            XCTAssertNotNil(resultSegment.continuationToken, @"No continuation token where there should be one.");
            NSArray *resultArray = resultSegment.blobs;
            
            XCTAssertNil(error, @"Error in listing blobs.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            XCTAssertTrue(resultArray.count >= 3, @"Incorrect number of blobs returned.");
            
            for (int i = 0; i < resultArray.count; i++)
            {
                AZSCloudBlob *blob = (AZSCloudBlob *)resultArray[i];
                XCTAssertTrue([blob.blobName isEqualToString:((AZSCloudBlob *)blobs[i]).blobName], @"Incorrect blob returned.");
                XCTAssertTrue(blob.metadata.count == 0, @"Metadata returned where there should be none.");
                [self checkBlobPropertiesWithBlob:blob isCommitted:YES isSnapshot:NO];
            }
            
            [semaphore signal];
        }];
    }];
    [semaphore wait];
}

- (void)testContainerListBlobsSegmentedFlatWithMaxResultsAll
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    [self createBlobsForListingTestsWithCompletionHandler:^(NSArray *blobs, NSString *blobNamePrefix) {
        NSMutableArray *arrayToPopulate = [NSMutableArray arrayWithCapacity:6];
        [self listAllBlobsFlatInContainer:self.blobContainer arrayToPopulate:arrayToPopulate continuationToken:nil prefix:nil blobListingDetails:AZSBlobListingDetailsNone maxResults:1 completionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in listing blobs.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            XCTAssertTrue(arrayToPopulate.count == 4, @"Incorrect number of blobs returned.");
            
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[0]).blobName isEqualToString:((AZSCloudBlob *)blobs[0]).blobName], @"Incorrect blob returned.");
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[1]).blobName isEqualToString:((AZSCloudBlob *)blobs[1]).blobName], @"Incorrect blob returned.");
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[2]).blobName isEqualToString:((AZSCloudBlob *)blobs[2]).blobName], @"Incorrect blob returned.");
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[3]).blobName isEqualToString:((AZSCloudBlob *)blobs[3]).blobName], @"Incorrect blob returned.");
            
            for (int i = 0; i < arrayToPopulate.count; i++)
            {
                AZSCloudBlob *blob = (AZSCloudBlob *)arrayToPopulate[i];
                XCTAssertTrue(blob.metadata.count == 0, @"Metadata returned where there should be none.");
                [self checkBlobPropertiesWithBlob:blob isCommitted:YES isSnapshot:NO];
            }
            
            [semaphore signal];
        }];
    }];
    [semaphore wait];
}

- (void)testContainerListBlobsSegmentedFlatListingDetailsSnapshots
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    [self createBlobsForListingTestsWithCompletionHandler:^(NSArray *blobs, NSString *blobNamePrefix) {
        NSMutableArray *arrayToPopulate = [NSMutableArray arrayWithCapacity:6];
        [self listAllBlobsFlatInContainer:self.blobContainer arrayToPopulate:arrayToPopulate continuationToken:nil prefix:nil blobListingDetails:AZSBlobListingDetailsSnapshots maxResults:-1 completionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in listing blobs.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            XCTAssertTrue(arrayToPopulate.count == 5, @"Incorrect number of blobs returned.");
            
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[0]).blobName isEqualToString:((AZSCloudBlob *)blobs[5]).blobName], @"Incorrect blob returned.");
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[0]).snapshotTime isEqualToString:((AZSCloudBlob *)blobs[5]).snapshotTime], @"Incorrect blob returned.");
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[1]).blobName isEqualToString:((AZSCloudBlob *)blobs[0]).blobName], @"Incorrect blob returned.");
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[2]).blobName isEqualToString:((AZSCloudBlob *)blobs[1]).blobName], @"Incorrect blob returned.");
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[3]).blobName isEqualToString:((AZSCloudBlob *)blobs[2]).blobName], @"Incorrect blob returned.");
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[4]).blobName isEqualToString:((AZSCloudBlob *)blobs[3]).blobName], @"Incorrect blob returned.");
            
            for (int i = 0; i < arrayToPopulate.count; i++)
            {
                AZSCloudBlob *blob = (AZSCloudBlob *)arrayToPopulate[i];
                XCTAssertTrue(blob.metadata.count == 0, @"Metadata returned where there should be none.");
                [self checkBlobPropertiesWithBlob:blob isCommitted:YES isSnapshot:(i == 0)];
            }
            
            [semaphore signal];
        }];
    }];
    [semaphore wait];
}

- (void)testContainerListBlobsSegmentedFlatListingDetailsMetadata
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    [self createBlobsForListingTestsWithCompletionHandler:^(NSArray *blobs, NSString *blobNamePrefix) {
        NSMutableArray *arrayToPopulate = [NSMutableArray arrayWithCapacity:6];
        [self listAllBlobsFlatInContainer:self.blobContainer arrayToPopulate:arrayToPopulate continuationToken:nil prefix:nil blobListingDetails:AZSBlobListingDetailsMetadata maxResults:-1 completionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in listing blobs.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            XCTAssertTrue(arrayToPopulate.count == 4, @"Incorrect number of blobs returned.");
            
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[0]).blobName isEqualToString:((AZSCloudBlob *)blobs[0]).blobName], @"Incorrect blob returned.");
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[1]).blobName isEqualToString:((AZSCloudBlob *)blobs[1]).blobName], @"Incorrect blob returned.");
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[1]).metadata[@"sampleMetadataKey"] isEqualToString:((AZSCloudBlob *)blobs[1]).metadata[@"sampleMetadataKey"]], @"Incorrect blob returned.");
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[2]).blobName isEqualToString:((AZSCloudBlob *)blobs[2]).blobName], @"Incorrect blob returned.");
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[3]).blobName isEqualToString:((AZSCloudBlob *)blobs[3]).blobName], @"Incorrect blob returned.");
            
            for (int i = 0; i < arrayToPopulate.count; i++)
            {
                AZSCloudBlob *blob = (AZSCloudBlob *)arrayToPopulate[i];
                if (i != 1)
                {
                    XCTAssertTrue(blob.metadata.count == 0, @"Metadata returned where there should be none.");
                }
                [self checkBlobPropertiesWithBlob:blob isCommitted:YES isSnapshot:NO];
            }
            
            [semaphore signal];
        }];
    }];
    [semaphore wait];
}

- (void)testContainerListBlobsSegmentedFlatListingDetailsUncommitted
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    [self createBlobsForListingTestsWithCompletionHandler:^(NSArray *blobs, NSString *blobNamePrefix) {
        NSMutableArray *arrayToPopulate = [NSMutableArray arrayWithCapacity:6];
        [self listAllBlobsFlatInContainer:self.blobContainer arrayToPopulate:arrayToPopulate continuationToken:nil prefix:nil blobListingDetails:AZSBlobListingDetailsUncommittedBlobs maxResults:-1 completionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in listing blobs.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            XCTAssertTrue(arrayToPopulate.count == 5, @"Incorrect number of blobs returned.");
            
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[0]).blobName isEqualToString:((AZSCloudBlob *)blobs[0]).blobName], @"Incorrect blob returned.");
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[1]).blobName isEqualToString:((AZSCloudBlob *)blobs[1]).blobName], @"Incorrect blob returned.");
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[2]).blobName isEqualToString:((AZSCloudBlob *)blobs[2]).blobName], @"Incorrect blob returned.");
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[3]).blobName isEqualToString:((AZSCloudBlob *)blobs[3]).blobName], @"Incorrect blob returned.");
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[4]).blobName isEqualToString:((AZSCloudBlob *)blobs[4]).blobName], @"Incorrect blob returned.");
            
            for (int i = 0; i < arrayToPopulate.count; i++)
            {
                AZSCloudBlob *blob = (AZSCloudBlob *)arrayToPopulate[i];
                XCTAssertTrue(blob.metadata.count == 0, @"Metadata returned where there should be none.");
                [self checkBlobPropertiesWithBlob:blob isCommitted:(i != 4) isSnapshot:NO];
            }
            
            [semaphore signal];
        }];
    }];
    [semaphore wait];
}

- (void)testContainerListBlobsSegmentedFlatListingDetailsCopy
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    [self createBlobsForListingTestsWithCompletionHandler:^(NSArray *blobs, NSString *blobNamePrefix) {
        NSMutableArray *arrayToPopulate = [NSMutableArray arrayWithCapacity:6];
        [self listAllBlobsFlatInContainer:self.blobContainer arrayToPopulate:arrayToPopulate continuationToken:nil prefix:nil blobListingDetails:AZSBlobListingDetailsCopy maxResults:-1 completionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in listing blobs.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            XCTAssertTrue(arrayToPopulate.count == 4, @"Incorrect number of blobs returned.");
            
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[0]).blobName isEqualToString:((AZSCloudBlob *)blobs[0]).blobName], @"Incorrect blob returned.");
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[1]).blobName isEqualToString:((AZSCloudBlob *)blobs[1]).blobName], @"Incorrect blob returned.");
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[2]).blobName isEqualToString:((AZSCloudBlob *)blobs[2]).blobName], @"Incorrect blob returned.");
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[3]).blobName isEqualToString:((AZSCloudBlob *)blobs[3]).blobName], @"Incorrect blob returned.");

            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[3]).blobCopyState.operationId isEqualToString:((AZSCloudBlob *)blobs[3]).blobCopyState.operationId], @"Copy results not populated correctly.");
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[3]).blobCopyState.source.path isEqualToString:((AZSCloudBlob *)blobs[2]).storageUri.primaryUri.path], @"Copy results not populated correctly.");
            XCTAssertTrue(((AZSCloudBlob *)arrayToPopulate[3]).blobCopyState.copyStatus != AZSCopyStatusInvalid, @"Copy results not populated correctly.");
            XCTAssertTrue(((AZSCloudBlob *)arrayToPopulate[3]).blobCopyState.bytesCopied.integerValue == 14, @"Copy results not populated correctly.");
            XCTAssertTrue(((AZSCloudBlob *)arrayToPopulate[3]).blobCopyState.totalBytes.integerValue == 14, @"Copy results not populated correctly.");
            XCTAssertTrue(((AZSCloudBlob *)arrayToPopulate[3]).blobCopyState.completionTime != nil, @"Copy results not populated correctly.");
            
            for (int i = 0; i < arrayToPopulate.count; i++)
            {
                AZSCloudBlob *blob = (AZSCloudBlob *)arrayToPopulate[i];
                XCTAssertTrue(blob.metadata.count == 0, @"Metadata returned where there should be none.");
                [self checkBlobPropertiesWithBlob:blob isCommitted:YES isSnapshot:NO];
            }
            
            [semaphore signal];
        }];
    }];
    [semaphore wait];
}

- (void)testContainerListBlobsSegmentedFlatListingDetailsAll
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];
    
    [self createBlobsForListingTestsWithCompletionHandler:^(NSArray *blobs, NSString *blobNamePrefix) {
        NSMutableArray *arrayToPopulate = [NSMutableArray arrayWithCapacity:6];
        [self listAllBlobsFlatInContainer:self.blobContainer arrayToPopulate:arrayToPopulate continuationToken:nil prefix:nil blobListingDetails:AZSBlobListingDetailsAll maxResults:-1 completionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in listing blobs.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            XCTAssertTrue(arrayToPopulate.count == 6, @"Incorrect number of blobs returned.");
            
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[0]).blobName isEqualToString:((AZSCloudBlob *)blobs[5]).blobName], @"Incorrect blob returned.");
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[1]).blobName isEqualToString:((AZSCloudBlob *)blobs[0]).blobName], @"Incorrect blob returned.");
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[2]).blobName isEqualToString:((AZSCloudBlob *)blobs[1]).blobName], @"Incorrect blob returned.");
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[2]).metadata[@"sampleMetadataKey"] isEqualToString:((AZSCloudBlob *)blobs[1]).metadata[@"sampleMetadataKey"]], @"Incorrect blob returned.");
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[3]).blobName isEqualToString:((AZSCloudBlob *)blobs[2]).blobName], @"Incorrect blob returned.");
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[4]).blobName isEqualToString:((AZSCloudBlob *)blobs[3]).blobName], @"Incorrect blob returned.");
            
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[4]).blobCopyState.operationId isEqualToString:((AZSCloudBlob *)blobs[3]).blobCopyState.operationId], @"Copy results not populated correctly.");
            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[4]).blobCopyState.source.path isEqualToString:((AZSCloudBlob *)blobs[2]).storageUri.primaryUri.path], @"Copy results not populated correctly.");
            XCTAssertTrue(((AZSCloudBlob *)arrayToPopulate[4]).blobCopyState.copyStatus != AZSCopyStatusInvalid, @"Copy results not populated correctly.");
            XCTAssertTrue(((AZSCloudBlob *)arrayToPopulate[4]).blobCopyState.bytesCopied.integerValue == 14, @"Copy results not populated correctly.");
            XCTAssertTrue(((AZSCloudBlob *)arrayToPopulate[4]).blobCopyState.totalBytes.integerValue == 14, @"Copy results not populated correctly.");
            XCTAssertTrue(((AZSCloudBlob *)arrayToPopulate[4]).blobCopyState.completionTime != nil, @"Copy results not populated correctly.");

            XCTAssertTrue([((AZSCloudBlob *)arrayToPopulate[5]).blobName isEqualToString:((AZSCloudBlob *)blobs[4]).blobName], @"Incorrect blob returned.");
            
            for (int i = 0; i < arrayToPopulate.count; i++)
            {
                AZSCloudBlob *blob = (AZSCloudBlob *)arrayToPopulate[i];
                if (i != 2)
                {
                    XCTAssertTrue(blob.metadata.count == 0, @"Metadata returned where there should be none.");
                }
                [self checkBlobPropertiesWithBlob:blob isCommitted:(i != 5) isSnapshot:(i == 0)];
            }
            
            [semaphore signal];
        }];
    }];
    [semaphore wait];
}

-(void)testContainerListBlobsBlockPageAppend
{
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    AZSCloudAppendBlob *appendBlob = [self.blobContainer appendBlobReferenceFromName:@"appendBlob"];
    AZSCloudBlockBlob *blockBlob = [self.blobContainer blockBlobReferenceFromName:@"blockBlob"];
    AZSCloudPageBlob *pageBlob = [self.blobContainer pageBlobReferenceFromName:@"pageBlob"];
    
    [appendBlob createWithCompletionHandler:^(NSError *error) {
        XCTAssertNil(error, @"Error in creating append blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        [blockBlob uploadFromText:@"sample blob text" completionHandler:^(NSError *error) {
            XCTAssertNil(error, @"Error in creating block blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            [pageBlob createWithSize:[NSNumber numberWithInt:512*10] completionHandler:^(NSError *error) {
                XCTAssertNil(error, @"Error in creating block blob.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                
                NSMutableArray *blobs = [NSMutableArray arrayWithCapacity:3];
                [AZSTestHelpers listAllInDirectoryOrContainer:self.blobContainer useFlatBlobListing:YES blobArrayToPopulate:blobs directoryArrayToPopulate:nil continuationToken:nil prefix:nil blobListingDetails:AZSBlobListingDetailsAll maxResults:5000 completionHandler:^(NSError *error) {
                    XCTAssertNil(error, @"Error in listing blobs.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                    XCTAssertEqual(3, blobs.count, @"Incorrect number of blobs returned.");
                    
                    XCTAssertEqualObjects(@"appendBlob", ((AZSCloudBlob *)blobs[0]).blobName, @"Incorrect blob name returned.");
                    XCTAssertEqual(AZSBlobTypeAppendBlob, ((AZSCloudBlob *)blobs[0]).properties.blobType, @"Incorrect blob type returned.");
                    XCTAssertTrue([blobs[0] respondsToSelector:NSSelectorFromString(@"appendBlockWithData:contentMD5:completionHandler:")], @"Incorrect blob class returned.");

                    XCTAssertEqualObjects(@"blockBlob", ((AZSCloudBlob *)blobs[1]).blobName, @"Incorrect blob name returned.");
                    XCTAssertEqual(AZSBlobTypeBlockBlob, ((AZSCloudBlob *)blobs[1]).properties.blobType, @"Incorrect blob type returned.");
                    XCTAssertTrue([blobs[1] respondsToSelector:NSSelectorFromString(@"uploadBlockFromData:blockID:completionHandler:")], @"Incorrect blob class returned.");

                    XCTAssertEqualObjects(@"pageBlob", ((AZSCloudBlob *)blobs[2]).blobName, @"Incorrect blob name returned.");
                    XCTAssertEqual(AZSBlobTypePageBlob, ((AZSCloudBlob *)blobs[2]).properties.blobType, @"Incorrect blob type returned.");
                    XCTAssertTrue([blobs[2] respondsToSelector:NSSelectorFromString(@"uploadPagesWithData:startOffset:contentMD5:completionHandler:")], @"Incorrect blob class returned.");

                    dispatch_semaphore_signal(semaphore);
                }];
            }];
        }];
    }];
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
}

-(void)testContainerExists
{
    AZSTestSemaphore *semaphore = [[AZSTestSemaphore alloc] init];

    NSString *newContainerName = [NSString stringWithFormat:@"%@1", self.containerName];
    // Check that Exists, CreateIfNotExists, and DeleteIfExists all do the right thing in both the exists and not-exists cases.
    
    AZSCloudBlobContainer *newContainer = [self.blobClient containerReferenceFromName:newContainerName];
    [newContainer existsWithCompletionHandler:^(NSError *error, BOOL exists) {
        XCTAssertNil(error, @"Error in checking container existence.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
        XCTAssertFalse(exists, @"Exists returned YES for a non-existant container.");
        
        [newContainer deleteContainerIfExistsWithCompletionHandler:^(NSError *error, BOOL success) {
            XCTAssertNil(error, @"Error in deleteIfExists.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
            XCTAssertFalse(success, @"deleteIfExists returned YES for a non-existant container.");
            
            [newContainer createContainerIfNotExistsWithCompletionHandler:^(NSError *error, BOOL success) {
                XCTAssertNil(error, @"Error in createIfNotExists.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                XCTAssertTrue(success, @"createIfNotExists returned NO for a non-existant container.");
                
                [newContainer createContainerIfNotExistsWithCompletionHandler:^(NSError *error, BOOL success) {
                    XCTAssertNil(error, @"Error in createIfNotExists.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                    XCTAssertFalse(success, @"createIfNotExists returned YES for an existant container.");
                    
                    [newContainer existsWithCompletionHandler:^(NSError *error, BOOL exists) {
                        XCTAssertNil(error, @"Error in checking container existence.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                        XCTAssertTrue(exists, @"Exists returned NO for an existant container.");
                        
                        [newContainer deleteContainerIfExistsWithCompletionHandler:^(NSError *error, BOOL success) {
                            XCTAssertNil(error, @"Error in deleteIfExists.  Error code = %ld, error domain = %@, error userinfo = %@", (long)error.code, error.domain, error.userInfo);
                            XCTAssertTrue(success, @"deleteIfExists returned NO for an existant container.");
                            [semaphore signal];
                        }];
                    }];
                }];
            }];
        }];
    }];
    [semaphore wait];
}

@end