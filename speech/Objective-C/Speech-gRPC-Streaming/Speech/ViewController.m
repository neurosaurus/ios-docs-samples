//
// Copyright 2016 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import <AVFoundation/AVFoundation.h>

#import "ViewController.h"
#import "AudioController.h"
#import "SpeechRecognitionService.h"
#import "google/cloud/speech/v1/CloudSpeech.pbrpc.h"

@interface ViewController () <AudioControllerDelegate>
@property (nonatomic, strong) IBOutlet UITextView *textView;
@property (nonatomic, strong) NSMutableData *audioData;
@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  [AudioController sharedInstance].delegate = self;
}

- (IBAction)recordAudio:(id)sender {
  AVAudioSession *audioSession = [AVAudioSession sharedInstance];
  [audioSession setCategory:AVAudioSessionCategoryRecord error:nil];

  _audioData = [[NSMutableData alloc] init];
  [[AudioController sharedInstance] prepare];
  [[AudioController sharedInstance] start];
}

- (IBAction)stopAudio:(id)sender {
  [[AudioController sharedInstance] stop];
  [[SpeechRecognitionService sharedInstance] stopStreaming];
}

- (void) processSampleData:(NSData *)data
{
  [self.audioData appendData:data];
  NSInteger frameCount = [data length] / 2;
  int16_t *samples = (int16_t *) [data bytes];
  int64_t sum = 0;
  for (int i = 0; i < frameCount; i++) {
    sum += abs(samples[i]);
  }
  NSLog(@"audio %d %d", (int) frameCount, (int) (sum * 1.0 / frameCount));

  if ([self.audioData length] > 16384) {
    NSLog(@"SENDING");
    [[SpeechRecognitionService sharedInstance] streamAudioData:self.audioData
                                                withCompletion:^(RecognizeResponse *response, NSError *error) {
                                                  if (response) {
                                                    BOOL finished = NO;
                                                    NSLog(@"RESPONSE RECEIVED");
                                                    if (error) {
                                                      NSLog(@"ERROR: %@", error);
                                                    } else {
                                                      NSLog(@"RESPONSE: %@", response);
                                                      for (SpeechRecognitionResult *result in response.resultsArray) {
                                                        if (result.isFinal) {
                                                          finished = YES;
                                                        }
                                                      }
                                                      _textView.text = [response description];
                                                    }
                                                    if (finished) {
                                                      [self stopAudio:nil];
                                                    }
                                                  } else {
                                                    [self stopAudio:nil];
                                                  }
                                                }];
    self.audioData = [[NSMutableData alloc] init];
  }
}

@end

