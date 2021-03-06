//
//  UIScrollView+ADKInfiniteScrollingView.m
//  AppDevKit
//
//  Created by Chih Feng Sung on 12/24/13.
//  Copyright © 2013, Yahoo Inc.
//  Licensed under the terms of the BSD License.
//  Please see the LICENSE file in the project root for terms.
//

#import <objc/runtime.h>

#import "UIScrollView+ADKInfiniteScrollingView.h"

@interface UIScrollView ()

@property (nonatomic, readonly) CGFloat infiniteScrollingViewHeight;
@property (nonatomic, weak) ADKInfiniteScrollingContentView *infiniteScrollingContentView;
@property (nonatomic, weak) UIView <ADKInfiniteScrollingViewProtocol> *infiniteScrollingHandleView;

@end


@interface ADKInfiniteScrollingContentView ()

- (void)resetScrollViewContentInset;
- (void)setScrollViewContentInsetForLoading;
- (void)setScrollViewContentInset:(UIEdgeInsets)contentInset;
- (void)updateLayout;

@property (nonatomic, copy) void (^infiniteScrollingActionHandler)(void);
@property (nonatomic, weak) UIScrollView *scrollView;
@property (nonatomic, assign) CGFloat originalTopInset;
@property (nonatomic, assign) CGFloat originalBottomInset;
@property (nonatomic, assign) ADKInfiniteScrollingState state;
@property (nonatomic, assign) ADKInfiniteScrollingState previousState;
@property (nonatomic, assign) BOOL isObserving;

@end


@implementation UIScrollView (ADKInfiniteScrollingView)

NSString * const infiniteScrollingContentViewKey;
NSString * const infiniteScrollingHandleViewKey;
@dynamic showInfiniteScrolling, infiniteScrollingContentView;

- (void)ADKAddInfiniteScrollingWithHandleView:(UIView<ADKInfiniteScrollingViewProtocol> *)infiniteScrollingHandleView actionHandler:(void (^)(void))actionHandler
{
    ADKInfiniteScrollingContentView *infiniteScrollingContentView = self.infiniteScrollingContentView;
    if (!infiniteScrollingContentView) {
        CGRect scrollingViewFrame = CGRectMake(0.0f, self.contentSize.height, CGRectGetWidth(self.bounds), CGRectGetHeight(infiniteScrollingHandleView.bounds));
        ADKInfiniteScrollingContentView *infiniteScrollingContentView = [[ADKInfiniteScrollingContentView alloc] initWithFrame:scrollingViewFrame];
        infiniteScrollingContentView.scrollView = self;
        [self addSubview:infiniteScrollingContentView];
        [infiniteScrollingContentView addSubview:infiniteScrollingHandleView];
        
        infiniteScrollingContentView.originalTopInset = self.contentInset.top;
        infiniteScrollingContentView.originalBottomInset = self.contentInset.bottom;
        infiniteScrollingContentView.infiniteScrollingActionHandler = actionHandler;
        self.infiniteScrollingContentView = infiniteScrollingContentView;
        self.infiniteScrollingHandleView = infiniteScrollingHandleView;
        self.showInfiniteScrolling = YES;
        
        [infiniteScrollingContentView updateLayout];
    }
}

- (void)ADKTriggerInfiniteScrollingWithAnimation:(BOOL)animated
{
    ADKInfiniteScrollingContentView *infiniteScrollingContentView = self.infiniteScrollingContentView;
    if (infiniteScrollingContentView.state == ADKInfiniteScrollingStateLoading || infiniteScrollingContentView.hidden) {
        return;
    }
    
    infiniteScrollingContentView.state = ADKInfiniteScrollingStateTriggered;
    
    if (!animated) {
        infiniteScrollingContentView.state = ADKInfiniteScrollingStateLoading;
    } else {
        [infiniteScrollingContentView startAnimating];
    }
}

#pragma mark - Setter & Getter

- (CGFloat)infiniteScrollingViewHeight
{
    return CGRectGetHeight(self.infiniteScrollingContentView.frame);
}

- (void)setInfiniteScrollingContentView:(ADKInfiniteScrollingContentView *)infiniteScrollingContentView
{
    [self willChangeValueForKey:@"InfiniteScrollingContentView"];
    objc_setAssociatedObject(self, &infiniteScrollingContentViewKey, infiniteScrollingContentView, OBJC_ASSOCIATION_ASSIGN);
    [self didChangeValueForKey:@"InfiniteScrollingContentView"];
}

- (ADKInfiniteScrollingContentView *)infiniteScrollingContentView
{
    return objc_getAssociatedObject(self, &infiniteScrollingContentViewKey);
}

- (void)setInfiniteScrollingHandleView:(UIView<ADKInfiniteScrollingViewProtocol> *)infiniteScrollingHandleView
{
    [self willChangeValueForKey:@"InfiniteScrollingHandleView"];
    objc_setAssociatedObject(self, &infiniteScrollingHandleViewKey, infiniteScrollingHandleView, OBJC_ASSOCIATION_ASSIGN);
    [self didChangeValueForKey:@"InfiniteScrollingHandleView"];
}

- (UIView <ADKInfiniteScrollingViewProtocol> *)infiniteScrollingHandleView
{
    return objc_getAssociatedObject(self, &infiniteScrollingHandleViewKey);
}

- (void)setShowInfiniteScrolling:(BOOL)showInfiniteScrolling
{
    ADKInfiniteScrollingContentView *infiniteScrollingContentView = self.infiniteScrollingContentView;
    if (infiniteScrollingContentView) {
        infiniteScrollingContentView.hidden = !showInfiniteScrolling;
        if (showInfiniteScrolling) {
            if (!infiniteScrollingContentView.isObserving) {
                [self addObserver:infiniteScrollingContentView forKeyPath:@"contentOffset" options:NSKeyValueObservingOptionNew context:nil];
                [self addObserver:infiniteScrollingContentView forKeyPath:@"contentSize" options:NSKeyValueObservingOptionNew context:nil];
                infiniteScrollingContentView.isObserving = YES;
            }
        } else {
            if (infiniteScrollingContentView.isObserving) {
                [self removeObserver:infiniteScrollingContentView forKeyPath:@"contentOffset"];
                [self removeObserver:infiniteScrollingContentView forKeyPath:@"contentSize"];
                infiniteScrollingContentView.isObserving = NO;
            }
        }
    }
}

- (BOOL)showInfiniteScrolling
{
    ADKInfiniteScrollingContentView *infiniteScrollingContentView = self.infiniteScrollingContentView;
    if (infiniteScrollingContentView) {
        return !infiniteScrollingContentView.hidden;
    }
    return NO;
}

- (void)willRemoveSubview:(UIView *)subview
{
    ADKInfiniteScrollingContentView *infiniteScrollingContentView = self.infiniteScrollingContentView;
    if (subview == infiniteScrollingContentView && infiniteScrollingContentView.isObserving) {
        [self removeObserver:infiniteScrollingContentView forKeyPath:@"contentOffset"];
        [self removeObserver:infiniteScrollingContentView forKeyPath:@"contentSize"];
        infiniteScrollingContentView.isObserving = NO;
    }
    [super willRemoveSubview:subview];
}

@end


@implementation ADKInfiniteScrollingContentView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.state = ADKInfiniteScrollingStateStopped;
    }
    
    return self;
}

- (void)setState:(ADKInfiniteScrollingState)state
{
    if (self.state != state) {
        _state = state;
        UIView <ADKInfiniteScrollingViewProtocol> *infiniteScrollingHandleView = self.scrollView.infiniteScrollingHandleView;
        switch (self.state) {
            case ADKInfiniteScrollingStateStopped:
                [self resetScrollViewContentInset];
                if ([infiniteScrollingHandleView respondsToSelector:@selector(ADKInfiniteScrollingStopped:)]) {
                    [infiniteScrollingHandleView ADKInfiniteScrollingStopped:self.scrollView];
                }
                break;
            case ADKInfiniteScrollingStateDragging:
                if ([infiniteScrollingHandleView respondsToSelector:@selector(ADKInfiniteScrollingDragging:)]) {
                    [infiniteScrollingHandleView ADKInfiniteScrollingDragging:self.scrollView];
                }
                break;
            case ADKInfiniteScrollingStateTriggered:
                if ([infiniteScrollingHandleView respondsToSelector:@selector(ADKInfiniteScrollingTriggered:)]) {
                    [infiniteScrollingHandleView ADKInfiniteScrollingTriggered:self.scrollView];
                }
                break;
            case ADKInfiniteScrollingStateLoading:
                [self setScrollViewContentInsetForLoading];
                if ([infiniteScrollingHandleView respondsToSelector:@selector(ADKInfiniteScrollingLoading:)]) {
                    [infiniteScrollingHandleView ADKInfiniteScrollingLoading:self.scrollView];
                }
                if (self.previousState == ADKInfiniteScrollingStateTriggered && self.infiniteScrollingActionHandler) {
                    self.infiniteScrollingActionHandler();
                }
                break;
        }
        
        self.previousState = state;
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"contentOffset"]) {
        CGPoint offsetPoint = [[change valueForKey:NSKeyValueChangeNewKey] CGPointValue];
        [self scrollViewDidScroll:offsetPoint];
    } else if ([keyPath isEqualToString:@"contentSize"]) {
        [self updateLayout];
    }
}

- (void)scrollViewDidScroll:(CGPoint)contentOffset
{
    CGFloat visibleThreshold = (contentOffset.y + CGRectGetHeight(self.scrollView.bounds) - self.scrollView.contentSize.height) / (self.scrollView.infiniteScrollingViewHeight * 1.0f);
    visibleThreshold = MAX(visibleThreshold, 0.0f);
    visibleThreshold = MIN(visibleThreshold, 1.0f);

    if (self.autoFadeEffect) {
        self.alpha = visibleThreshold;
    } else {
        self.alpha = 1.0f;
    }

    if (self.state != ADKInfiniteScrollingStateLoading) {
        // Infinite scrolling feature will trigger when user scroll to bottom over specific distance of infiniteScrollingViewHeight. (Default is 1.0 time height)
        CGFloat triggerDistanceTimes = 1.0f;
        UIView <ADKInfiniteScrollingViewProtocol> *infiniteScrollingHandleView = self.scrollView.infiniteScrollingHandleView;
        if ([infiniteScrollingHandleView respondsToSelector:@selector(ADKInfiniteScrollingTriggerDistanceTimes:)]) {
            if ([infiniteScrollingHandleView ADKInfiniteScrollingTriggerDistanceTimes:self.scrollView] >= 1.0f) {
                triggerDistanceTimes = [infiniteScrollingHandleView ADKInfiniteScrollingTriggerDistanceTimes:self.scrollView];
            }
        }

        /*
         +---------+
         | content |
         | size    |
         |         |
  frame  |         |
       +-----------+
       | |         |
       | |         |
       | |         |
       | |         |
       +-+---------+ -+-
       |           |  | adjustedContentInset.bottom
       +-----------+ -+-

 The bottom of visible port converted into coord system in content:
 contentOffset.y + (frame height - adjustedContentInset.bottom)

State diagram:

         released.1
      +-------------+
      v   drag.1    |       drag.3             released.2
 STOPPED -------> DRAGGING -------> TRIGGERED -----------> LOADING
   ^  ^    drag.2   |   ^    drag.4   |                     |
   |  +-------------+   +-------------+                     |
   |                                                        |
   +--------------------------------------------------------+
            implicitly done by stop animating

         */

        CGFloat contentInsetBottom =
#ifdef __IPHONE_11_0
            (@available(iOS 11.0, *)) ? self.scrollView.adjustedContentInset.bottom : self.scrollView.contentInset.bottom
#else
            self.scrollView.contentInset.bottom
#endif
        ;

        /*
         scrollDraggingThreshold is the distance from the end of content to the point where triggers loading.

         scrollDraggingOffset is the distance that user is dragging beyond the end of content.  It may be a negative value.
         */
        CGFloat scrollDraggingThreshold = self.scrollView.infiniteScrollingViewHeight * triggerDistanceTimes;
        CGFloat scrollDraggingOffset = self.scrollView.contentOffset.y + CGRectGetHeight(self.scrollView.frame) - contentInsetBottom - self.scrollView.contentSize.height;

        if (self.scrollView.isDragging) {
            if (self.state == ADKInfiniteScrollingStateStopped && scrollDraggingOffset > 0.0f) {
                // dragging.1
                self.state = ADKInfiniteScrollingStateDragging;
            } else if (self.state == ADKInfiniteScrollingStateDragging && scrollDraggingOffset <= 0.0f) {
                // dragging.2
                self.state = ADKInfiniteScrollingStateStopped;
            } else if (self.state == ADKInfiniteScrollingStateDragging && scrollDraggingOffset >= scrollDraggingThreshold) {
                // dragging.3
                self.state = ADKInfiniteScrollingStateTriggered;
            } else if (self.state == ADKInfiniteScrollingStateTriggered && scrollDraggingOffset < scrollDraggingThreshold) {
                // dragging.4
                self.state = ADKInfiniteScrollingStateDragging;
            }
        } else if (!self.scrollView.isDragging) {
            if (self.state == ADKInfiniteScrollingStateDragging && scrollDraggingOffset < scrollDraggingThreshold) {
                // released.1
                self.state = ADKInfiniteScrollingStateStopped;
            } else if (self.state == ADKInfiniteScrollingStateTriggered) {
                // released.2
                self.state = ADKInfiniteScrollingStateLoading;
            }
         }

        if (self.scrollView.isDragging && self.state == ADKInfiniteScrollingStateDragging) {
            if ([infiniteScrollingHandleView respondsToSelector:@selector(ADKInfiniteScrollView:draggingWithProgress:)]) {
                CGFloat progressValue = scrollDraggingOffset / scrollDraggingThreshold;
                [infiniteScrollingHandleView ADKInfiniteScrollView:self.scrollView draggingWithProgress:progressValue];
            }
        }
    }
}

- (void)resetScrollViewContentInset
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIEdgeInsets currentInsets = self.scrollView.contentInset;
        currentInsets.bottom = self.originalBottomInset;

        [self setScrollViewContentInset:currentInsets];
    });
}

- (void)setScrollViewContentInsetForLoading
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIEdgeInsets currentInsets = self.scrollView.contentInset;
        CGFloat contentInsetsBottom = self.scrollView.infiniteScrollingViewHeight + self.originalBottomInset;
        contentInsetsBottom = MAX(contentInsetsBottom, CGRectGetHeight(self.scrollView.bounds) - self.scrollView.contentSize.height + self.scrollView.infiniteScrollingViewHeight - self.originalTopInset);
        currentInsets.bottom = contentInsetsBottom;

        [self setScrollViewContentInset:currentInsets];
    });
}

- (void)setScrollViewContentInset:(UIEdgeInsets)contentInset
{
    self.scrollView.contentInset = contentInset;
}

- (void)startAnimating
{
    CGFloat contentOffsetBottom = self.scrollView.contentSize.height - CGRectGetHeight(self.scrollView.bounds) + self.scrollView.contentInset.bottom + self.scrollView.infiniteScrollingViewHeight;
    contentOffsetBottom = MAX(contentOffsetBottom, self.scrollView.infiniteScrollingViewHeight - self.originalTopInset);
    
    CGPoint scrollPoint = CGPointMake(self.scrollView.contentOffset.x, contentOffsetBottom);
    [UIView animateWithDuration:0.3f
                     animations:^{
                         self.scrollView.contentOffset = scrollPoint;
                     } completion:^(BOOL finished) {
                         // no-op
                     }];
    
    self.state = ADKInfiniteScrollingStateLoading;
}

- (void)stopAnimating
{
    self.state = ADKInfiniteScrollingStateStopped;
}

- (void)updateLayout
{
    CGFloat infiniteScrollPositionY = MAX(self.scrollView.contentSize.height, CGRectGetHeight(self.scrollView.bounds) - self.originalTopInset - self.originalBottomInset);
    CGRect scrollingViewFrame = CGRectMake(0.0f, infiniteScrollPositionY, CGRectGetWidth(self.scrollView.bounds), CGRectGetHeight(self.bounds));
    self.frame = scrollingViewFrame;
}


@end
