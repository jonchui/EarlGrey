//
// Copyright 2016 Google Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "Action/GREYChangeStepperAction.h"

#import "Action/GREYTapper.h"
#import "Additions/NSError+GREYAdditions.h"
#import "Additions/NSObject+GREYAdditions.h"
#import "Assertion/GREYAssertionDefines.h"
#import "Common/GREYDefines.h"
#import "Common/GREYError.h"
#import "Common/GREYObjectFormatter.h"
#import "Core/GREYInteraction.h"
#import "Matcher/GREYAllOf.h"
#import "Matcher/GREYMatchers.h"
#import "Matcher/GREYNot.h"

NSString *const kErrorDetailStepperKey = @"Stepper";
NSString *const kErrorDetailUserValueKey = @"UserValue";
NSString *const kErrorDetailStepMaxValueKey = @"StepMaxValue";
NSString *const kErrorDetailStepMinValueKey = @"StepMinValue";

@implementation GREYChangeStepperAction {
  /**
   *  The value by which the stepper should change.
   */
  double _value;
}

- (instancetype)initWithValue:(double)value {
  self = [super initWithName:[NSString stringWithFormat:@"Change stepper to %g", value]
                 constraints:grey_allOf(grey_interactable(),
                                        grey_not(grey_systemAlertViewShown()),
                                        grey_kindOfClass([UIStepper class]),
                                        nil)];
  if (self) {
    _value = value;
  }
  return self;
}

#pragma mark - GREYAction

- (BOOL)perform:(UIStepper *)stepper error:(__strong NSError **)errorOrNil {
  if (![self satisfiesConstraintsForElement:stepper error:errorOrNil]) {
    return NO;
  }

  if (_value > stepper.maximumValue || _value < stepper.minimumValue) {
    NSMutableDictionary *errorDetails = [[NSMutableDictionary alloc] init];

    errorDetails[kErrorDetailActionNameKey] = self.name;
    errorDetails[kErrorDetailStepperKey] = [stepper description];
    errorDetails[kErrorDetailUserValueKey] = [NSString stringWithFormat:@"%lf", _value];
    errorDetails[kErrorDetailStepMaxValueKey] =
        [NSString stringWithFormat:@"%lf", stepper.maximumValue];
    errorDetails[kErrorDetailStepMinValueKey] =
        [NSString stringWithFormat:@"%lf", stepper.minimumValue];
    errorDetails[kErrorDetailRecoverySuggestionKey] = @"Make sure the value for stepper lies "
                                                      @"in appropriate range";

    NSArray *keyOrder = @[ kErrorDetailActionNameKey,
                           kErrorDetailStepperKey,
                           kErrorDetailUserValueKey,
                           kErrorDetailStepMaxValueKey,
                           kErrorDetailStepMinValueKey,
                           kErrorDetailRecoverySuggestionKey ];

    NSString *reasonDetail = [GREYObjectFormatter formatDictionary:errorDetails
                                                            indent:GREYObjectFormatIndent
                                                         hideEmpty:YES
                                                          keyOrder:keyOrder];
    NSString *reason = [NSString stringWithFormat:@"Cannot set stepper value due to "
                                                  @"invalid user input.\n"
                                                  @"Exception with Action: %@\n",
                                                  reasonDetail];

    GREYFailWithDetails(reason, @"");

    return NO;
  }

  UIButton *minusButton;
  UIButton *plusButton;
  for (UIView *view in stepper.subviews) {
    if ([view isKindOfClass:[UIButton class]]) {
      // Another way to find the buttons is to compare the images from decrementImageForState:
      // and incrementImageForState:, but for now we just consider minus button on the left,
      // plus button of the right.
      if (CGRectGetMidX(view.frame) < CGRectGetMidX(stepper.bounds)) {
        minusButton = (UIButton *)view;
      } else {
        plusButton = (UIButton *)view;
      }
      if (minusButton && plusButton) {
        break;
      }
    }
  }

  if (!(minusButton && plusButton)) {
    NSString *description = [NSString stringWithFormat:@"Failed to find stepper buttons "
                                                       @"in stepper (S)"];
    NSDictionary *note = @{ @"S" : [stepper description] };

    GREYPopulateErrorNotedOrLog(errorOrNil,
                                kGREYInteractionErrorDomain,
                                kGREYInteractionActionFailedErrorCode,
                                description,
                                note);
    return NO;
  }

  UIButton *buttonToPress;
  int numberPressNeeded = 0;
  double currentValue = stepper.value;
  // If we need to increase the stepper's value
  if (currentValue < _value) {
    while (currentValue < _value) {
      numberPressNeeded++;
      currentValue += stepper.stepValue;
    }
    buttonToPress = plusButton;
  } else if (currentValue > _value) {
    while (currentValue > _value) {
      numberPressNeeded++;
      currentValue -= stepper.stepValue;
    }
    buttonToPress = minusButton;
  }
  if (currentValue != _value) {
    NSString *description = [NSString stringWithFormat:@"Failed to exactly step to %lf "
                                                       @"from current value %lf and step %lf.",
                                                       _value,
                                                       stepper.value,
                                                       stepper.stepValue];

    GREYPopulateErrorOrLog(errorOrNil,
                           kGREYInteractionErrorDomain,
                           kGREYInteractionActionFailedErrorCode,
                           description);

    return NO;
  }
  for (int i = 1; i <= numberPressNeeded; i++) {
    if (![GREYTapper tapOnElement:buttonToPress
                     numberOfTaps:1
                         location:[buttonToPress grey_accessibilityActivationPointRelativeToFrame]
                            error:errorOrNil]) {
      return NO;
    }
  }
  return YES;
}

@end
