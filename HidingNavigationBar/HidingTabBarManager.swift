//
//  HidingTabBarManager.swift
//  MS3
//
//  Created by Chris Mitchelmore on 12/04/2016.
//  Copyright © 2016 Marks & Spencer. All rights reserved.
//

import UIKit


public class HidingTabBarManager: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
    // The view controller that is part of the navigation stack
    unowned var viewController: UIViewController
    
    // The scrollView that will drive the contraction/expansion
    unowned var scrollView: UIScrollView
    unowned var headerView: UIView
    
    private var tabBarController: HidingViewController
    
    // Scroll calculation values
    private var topInset: CGFloat = 0
    private var previousYOffset = CGFloat.NaN
    private var isUpdatingValues = false
    
    // Hiding navigation bar state
    private var currentState = HidingNavigationBarState.Open
    
    public init(viewController: UIViewController, scrollView: UIScrollView, tabBarController: UITabBarController, headerView: UIView){
    
        self.viewController = viewController
        self.scrollView = scrollView
        self.tabBarController = HidingViewController(view: tabBarController.tabBar)
        self.headerView = headerView
        super.init()
        
        self.tabBarController.contractsUpwards = false
        self.tabBarController.expandedCenter = {[weak self] (view: UIView) -> CGPoint in
            let height = self?.viewController.view.frame.size.height ?? 0
            let point = CGPointMake(CGRectGetMidX(view.bounds), height - CGRectGetMidY(view.bounds))
            
            return point
        }
        // track panning on scroll view
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture))
        panGesture.delegate = self
        scrollView.addGestureRecognizer(panGesture)
    
        updateContentInsets()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(applicationDidBecomeActive), name: UIApplicationDidBecomeActiveNotification, object: nil)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    public func scrollViewDidScroll(scrollView: UIScrollView) {
        if scrollView.contentOffset.y <= 0 {
            scrollView.setContentOffset(CGPointMake(scrollView.contentOffset.x, 0), animated: false)
        }
    }
    
    //MARK: Public methods
    
    public func viewWillAppear(animated: Bool) {
        expand()
    }
    
    public func viewDidLayoutSubviews() {
        updateContentInsets()
    }
    
    public func viewWillDisappear(animated: Bool) {
        expand()
    }
    
    public func updateValues()	{
        isUpdatingValues = true
        
        var scrolledToTop = false
        
        if scrollView.contentInset.top == -scrollView.contentOffset.y {
            scrolledToTop = true
        }
        
        updateContentInsets()
        
        if scrolledToTop {
            var offset = scrollView.contentOffset
            offset.y = -scrollView.contentInset.top
            scrollView.contentOffset = offset
        }
        
        isUpdatingValues = false
    }
    
    public func shouldScrollToTop(){
        let top = headerView.frame.size.height
        updateScrollContentInsetTop(top)
        tabBarController.snap(false, completion: nil)
    }
    
    public func contract(){
        tabBarController.contract()
        
        previousYOffset = CGFloat.NaN
    
        handleScrolling()
    }
    
    public func expand() {
        tabBarController.expand()
        
        previousYOffset = CGFloat.NaN
        
        handleScrolling()
    }
    
    //MARK: NSNotification
    
    func applicationDidBecomeActive() {
        tabBarController.expand()
    }
    
    //MARK: Private methods
    
    private func isViewControllerVisible() -> Bool {
        return viewController.isViewLoaded() && viewController.view.window != nil
    }
    
    private func shouldHandleScrolling() -> Bool {
        // if scrolling down past top
        if scrollView.contentOffset.y <= -scrollView.contentInset.top && currentState == .Open {
            return false
        }

        let scrollFrame = UIEdgeInsetsInsetRect(scrollView.bounds, scrollView.contentInset)
        let scrollableAmount: CGFloat = scrollView.contentSize.height - CGRectGetHeight(scrollFrame)
        let scrollViewIsSuffecientlyLong: Bool = scrollableAmount > scrollView.frame.size.height * 3
        
        return isViewControllerVisible() && scrollViewIsSuffecientlyLong && !isUpdatingValues
    }
    
    private func handleScrolling(){
        if shouldHandleScrolling() == false {
            return
        }
        
        if isnan(previousYOffset) == false {
            // 1 - Calculate the delta
            var deltaY = previousYOffset - scrollView.contentOffset.y
            
            // 2 - Ignore any scrollOffset beyond the bounds
            let start = -topInset
            if previousYOffset < start {
                deltaY = min(0, deltaY - previousYOffset - start)
            }
            
            /* rounding to resolve a dumb issue with the contentOffset value */
            let end = floor(scrollView.contentSize.height - CGRectGetHeight(scrollView.bounds) + scrollView.contentInset.bottom - 0.5)
            if previousYOffset > end {
                deltaY = max(0, deltaY - previousYOffset + end)
            }
            
            // 3 - Update contracting variable
            if Float(fabs(deltaY)) > FLT_EPSILON {
                if deltaY < 0 {
                    currentState = .Contracting
                } else {
                    currentState = .Expanding
                }
            }
            
            tabBarController.updateYOffset(deltaY)
        }
        
        // update content Inset
        updateContentInsets()
        
        previousYOffset = scrollView.contentOffset.y
        
        // update the visible state
    
        if CGPointEqualToPoint(tabBarController.view.center, tabBarController.expandedCenterValue()) {
            currentState = .Open
        } else if CGPointEqualToPoint(tabBarController.view.center, tabBarController.contractedCenterValue()) {
            currentState = .Closed
        }
        
        
    }
    
    private func updateContentInsets() {
        updateScrollContentInsetTop(headerView.frame.size.height)
    }
    
    private func updateScrollContentInsetTop(top: CGFloat){ 
        var scrollInsets = scrollView.scrollIndicatorInsets
        scrollInsets.top = top
        
        scrollInsets.bottom = tabBarController.isContracted() ? 0 : -tabBarController.totalHeight()
        
        scrollView.scrollIndicatorInsets = scrollInsets
    }
    
    private func handleScrollingEnded(velocity: CGFloat) {
        let minVelocity: CGFloat = 500.0
        if isViewControllerVisible() == false || (tabBarController.isContracted() && velocity < minVelocity) {
            return
        }
        
    
        if currentState == .Contracting || currentState == .Expanding || velocity > minVelocity {
            var contracting: Bool = currentState == .Contracting
            
            if velocity > minVelocity {
                contracting = false
            }
            
            tabBarController.snap(contracting, completion: nil)
            previousYOffset = CGFloat.NaN
        }
    }
    
    //MARK: Scroll handling
    
    func handlePanGesture(gesture: UIPanGestureRecognizer){
        switch gesture.state {
        case .Began:
            topInset = headerView.frame.size.height
            handleScrolling()
        case .Changed:
            handleScrolling()
        default:
            let velocity = gesture.velocityInView(scrollView).y
            handleScrollingEnded(velocity)
        }
    }
    
    //MARK: UIGestureRecognizerDelegate
    
    public func gestureRecognizer(gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWithGestureRecognizer otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
}
