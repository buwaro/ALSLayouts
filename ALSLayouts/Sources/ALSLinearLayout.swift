/*
 * Copyright (C) 2006 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import UIKit

/**
 A Layout that arranges its children in a single column or a single row. The direction of
 the row can be set by assigning `orientation`.
 
 You can also specify gravity, which specifies the alignment of all the child elements by
 assigning `gravity` or specify that specific children
 grow to fill up any remaining space in the layout by setting the *weight* member of
 `ALSLayoutParams`.
 
 The default orientation is horizontal.
 
 See the [Linear Layout](https://developer.android.com/guide/topics/ui/layout/linear.html) guide.
 
 - Author: Mariotaku Lee
 - Date: Sep 4, 2016
 */
open class ALSLinearLayout: ALSBaseLayout, ALSBaselineSupport {
    
    fileprivate static let VERTICAL_GRAVITY_COUNT = 4
    
    fileprivate static let INDEX_CENTER_VERTICAL = 0
    fileprivate static let INDEX_TOP = 1
    fileprivate static let INDEX_BOTTOM = 2
    fileprivate static let INDEX_FILL = 3
    
    /**
     LinearLayout orientation
     */
    public enum Orientation: String {
        /**
         Layout items horizontally
         */
        case horizontal
        /**
         Layout items vertically
         */
        case vertical
    }
    
    /**
     Set how dividers should be shown between items in this layout
     */
    public struct ShowDividers: OptionSet {
        public let rawValue:Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        
        /**
         Don't show any dividers.
         */
        public static let None = ShowDividers(rawValue: 0)
        /**
         Show a divider at the beginning of the group.
         */
        public static let Beginning = ShowDividers(rawValue: 1)
        /**
         Show dividers between each item in the group.
         */
        public static let Middle = ShowDividers(rawValue: 2)
        /**
         Show a divider at the end of the group.
         */
        public static let End = ShowDividers(rawValue: 4)
    }
    
    /**
     Defines whether widgets contained in this layout are
     baseline-aligned or not.
     */
    @IBInspectable open var baselineAligned = true {
        didSet {
            self.setNeedsLayout()
        }
    }
    
    /**
     If this layout is part of another layout that is baseline aligned,
     use the child at this index as the baseline.
     
     
     Note: this is orthogonal to `baselineAligned`, which is concerned
     with whether the children of this layout are baseline aligned.
     */
    @IBInspectable open var baselineAlignedChildIndex = -1 {
        didSet {
            self.setNeedsLayout()
        }
    }
    
    /**
     Defines the desired weights sum. If unspecified the weights sum is computed
     at layout time by adding the layout_weight of each child.
     
     This can be used for instance to give a single child 50% of the total
     available space by giving it a `weight` of 0.5 and setting the
     `weightSum` to 1.0.
     */
    @IBInspectable open var weightSum: CGFloat = 0 {
        didSet {
            self.setNeedsLayout()
        }
    }
    
    /**
     When set to true, all children with a weight will be considered having
     the minimum size of the largest child. If false, all children are
     measured normally.
     
     Disabled by default.
     */
    @IBInspectable open var measureWithLargestChild: Bool = false {
        didSet {
            self.setNeedsLayout()
        }
    }
    
    @IBInspectable internal var orientationString: String {
        get { return self.orientation.rawValue }
        set { self.orientation = Orientation(rawValue: newValue)! }
    }
    
    /**
     Should the layout be a column or a row.
     Default value is .Horizontal
     */
    open var orientation: ALSLinearLayout.Orientation = .horizontal {
        didSet {
            self.setNeedsLayout()
        }
    }
    
    /**
     The additional offset to the child's baseline.
     We'll calculate the baseline of this layout as we measure vertically; for
     horizontal linear layouts, the offset of 0 is appropriate.
     */
    fileprivate var baselineChildTop: CGFloat = 0
    
    fileprivate var totalLength: CGFloat = 0
    
    fileprivate var maxAscent: [CGFloat]!
    fileprivate var maxDescent: [CGFloat]!
    
    /**
     Set an UIImage to be used as a divider between items.
     */
    @IBInspectable open var divider: UIImage! = nil {
        didSet {
            if (divider === oldValue) {
                return
            }
            if (divider != nil) {
                dividerSize = self.divider!.size
            } else {
                dividerSize = CGSize.zero
            }
            setNeedsLayout()
        }
    }
    
    @IBInspectable var showDividersString: String {
        get { return self.showDividers.rawString }
        set { self.showDividers = ShowDividers.parse(newValue) }
    }
    
    /**
     Set how dividers should be shown between items in this layout
     
     - SeeAlso: `ShowDividers`
     */
    open var showDividers: ShowDividers = .None {
        didSet {
            setNeedsLayout()
            setNeedsDisplay()
        }
    }
    
    /**
     Divider padding
     */
    @IBInspectable open var dividerPadding: CGFloat = 0 {
        didSet {
            setNeedsLayout()
            setNeedsDisplay()
        }
    }
    
    /**
     Get the size of the current divider size.
     */
    fileprivate(set) var dividerSize: CGSize = CGSize.zero
    
    /**
     implements `ALSBaselineSupport`
     */
    open func calculateBaselineBottomValue() -> CGFloat {
        if (baselineAlignedChildIndex < 0) {
            return CGFloat.nan
        }
        
        if (subviews.count <= baselineAlignedChildIndex) {
            fatalError("baselineAlignedChildIndex of LinearLayout set to an index that is out of bounds.")
        }
        
        let child = subviews[baselineAlignedChildIndex]
        let childBaseline = child.baselineBottomValue
        
        if (childBaseline.isNaN) {
            if (baselineAlignedChildIndex == 0) {
                // this is just the default case, safe to return -1
                return CGFloat.nan
            }
            // the user picked an index that points to something that doesn't
            // know how to calculate its baseline.
            fatalError("baselineAlignedChildIndex of LinearLayout points to a View that doesn't know how to get its baseline.")
        }
        
        // TODO: This should try to take into account the virtual offsets
        // (See getNextLocationOffset and getLocationOffset)
        // We should add to childTop:
        // sum([getNextLocationOffset(getChildAt(i)) / i < mBaselineAlignedChildIndex])
        // and also add:
        // getLocationOffset(child)
        var childTop = baselineChildTop
        
        if (orientation == .vertical) {
            let majorGravity = gravity & ALSGravity.VERTICAL_GRAVITY_MASK
            if (majorGravity != ALSGravity.TOP) {
                switch (majorGravity) {
                case ALSGravity.BOTTOM:
                    childTop = frame.bottom - frame.top - actualLayoutMargins.bottom - totalLength
                case ALSGravity.CENTER_VERTICAL:
                    childTop += (frame.bottom - frame.top - actualLayoutMargins.top - actualLayoutMargins.bottom - totalLength) / 2
                default: break
                }
            }
        }
        
        let lp = child.layoutParams
        return childTop + lp.marginTop + childBaseline
    }
    
    /// Measure subviews
    override func measureSubviews(_ size: CGSize) -> CGSize {
        let widthSpec: ALSLayoutParams.MeasureSpecMode = layoutParamsOrNull?.measuredWidthSpec ?? .exactly
        let heightSpec: ALSLayoutParams.MeasureSpecMode = layoutParamsOrNull?.measuredHeightSpec ?? .exactly
        
        let widthMeasureSpec: ALSLayoutParams.MeasureSpec = (size.width, widthSpec)
        let heightMeasureSpec: ALSLayoutParams.MeasureSpec = (size.height, heightSpec)
        if (orientation == .vertical) {
            return measureVertical(widthMeasureSpec, heightMeasureSpec)
        } else {
            return measureHorizontal(widthMeasureSpec, heightMeasureSpec)
        }
    }
    
    /// Layout subviews
    open override func layoutSubviews() {
        _ = measureSubviews(self.bounds.size)
        
        if (orientation == .vertical) {
            layoutVertical(self.frame)
        } else {
            layoutHorizontal(self.frame)
        }
        
    }
    
    /// Implementation draws dividers
    open override func draw(_ rect: CGRect) {
        if (divider == nil) {
            return
        }
        
        if (orientation == .vertical) {
            drawDividersVertical()
        } else {
            drawDividersHorizontal()
        }
    }
    
    internal func drawDividersVertical() {
        let count = virtualChildCount
        for i in 0..<count {
            if let child = getVirtualChildAt(i) , !child.layoutHidden {
                if (hasDividerBeforeChildAt(i)) {
                    let lp = child.layoutParams
                    let top = child.frame.top - lp.marginTop - dividerSize.height;
                    drawHorizontalDivider(top);
                }
            }
        }
        
        if (hasDividerBeforeChildAt(count)) {
            var bottom: CGFloat = 0;
            if let child = getLastNonGoneChild() {
                let lp = child.layoutParams
                bottom = child.frame.bottom + lp.marginBottom;
            } else {
                bottom = frame.height - actualLayoutMargins.bottom - dividerSize.height;
            }
            drawHorizontalDivider(bottom)
        }
    }
    
    /**
     Finds the last child that is not gone. The last child will be used as the reference for
     where the end divider should be drawn.
     */
    fileprivate func getLastNonGoneChild() -> UIView? {
        for i in (0..<virtualChildCount).reversed() {
            if let child = getVirtualChildAt(i) , !child.layoutHidden {
                return child
            }
        }
        return nil
    }
    
    internal func drawDividersHorizontal() {
        let count = virtualChildCount
        let isLayoutRtl = layoutDirection == .rightToLeft
        for i in 0..<count {
            if let child = getVirtualChildAt(i) , !child.layoutHidden {
                if (hasDividerBeforeChildAt(i)) {
                    let lp = child.layoutParams
                    let position: CGFloat
                    if (isLayoutRtl) {
                        position = child.frame.right + lp.marginAbsRight;
                    } else {
                        position = child.frame.left - lp.marginAbsLeft - dividerSize.width;
                    }
                    drawVerticalDivider(position);
                }
            }
        }
        
        if (hasDividerBeforeChildAt(count)) {
            let position: CGFloat
            if let child = getLastNonGoneChild() {
                let lp = child.layoutParams
                if (isLayoutRtl) {
                    position = child.frame.left - lp.marginAbsLeft - dividerSize.width;
                } else {
                    position = child.frame.right + lp.marginAbsRight;
                }
            } else {
                if (isLayoutRtl) {
                    position = actualLayoutMargins.left
                } else {
                    position = bounds.width - actualLayoutMargins.right - dividerSize.width;
                }
            }
            drawVerticalDivider(position);
        }
    }
    
    
    override func initLayoutParams(_ view: UIView, newParams: ALSLayoutParams) {
        // LinarLayout.LayoutParams' default gravity is -1
        newParams.gravity = -1
    }
    
    /**
     * Measures the children when the orientation of this LinearLayout is set
     * to [Orientation.VERTICAL].
     *
     * @param widthMeasureSpec  Horizontal space requirements as imposed by the parent.
     *
     * @param heightMeasureSpec Vertical space requirements as imposed by the parent.
     *
     * @see .orientation
     *
     * @see .onMeasure
     */
    internal func measureVertical(_ widthMeasureSpec: ALSLayoutParams.MeasureSpec, _ heightMeasureSpec: ALSLayoutParams.MeasureSpec) -> CGSize {
        self.totalLength = 0
        
        var maxWidth: CGFloat = 0
        var childState: ALSLayoutParams.MeasureStates = (.unspecified, .unspecified)
        var alternativeMaxWidth: CGFloat = 0
        var weightedMaxWidth: CGFloat = 0
        var allFillParent = true
        var totalWeight: CGFloat = 0
        
        let count = virtualChildCount
        
        let widthSpec: ALSLayoutParams.MeasureSpecMode = layoutParamsOrNull?.measuredWidthSpec ?? .exactly
        let heightSpec: ALSLayoutParams.MeasureSpecMode = layoutParamsOrNull?.measuredHeightSpec ?? .exactly
        
        var matchWidth = false
        var skippedMeasure = false
        
        let baselineChildIndex = baselineAlignedChildIndex
        let useLargestChild = self.measureWithLargestChild
        
        var largestChildHeight: CGFloat = CGFloat.leastNormalMagnitude
        var consumedExcessSpace: CGFloat = 0
        
        let layoutDirection = self.layoutDirection
        
        var measureIdx0: Int = 0
        while (measureIdx0 < count) {
            guard let child = getVirtualChildAt(measureIdx0) else {
                totalLength += measureNullChild(measureIdx0)
                measureIdx0 += 1
                continue
            }
            
            let lp = child.layoutParams
            
            lp.resolveLayoutDirection(layoutDirection)
            
            if (lp.hidden) {
                measureIdx0 += getChildrenSkipCount(child, index: measureIdx0) + 1 // combined with measureIdx0++
                continue
            }
            
            if (hasDividerBeforeChildAt(measureIdx0)) {
                self.totalLength += dividerSize.height
            }
            
            totalWeight += lp.weight
            
            let useExcessSpace = lp.heightDimension == 0 && lp.weight > 0
            if (heightSpec == .exactly && useExcessSpace) {
                // Optimization: don't bother measuring children who are only
                // laid out using excess space. These views will get measured
                // later if we have space to distribute.
                let totalLength = self.totalLength
                self.totalLength = max(totalLength, totalLength + lp.marginTop + lp.marginBottom)
                skippedMeasure = true
            } else {
                if (useExcessSpace) {
                    // The heightMode is either UNSPECIFIED or AT_MOST, and
                    // this child is only laid out using excess space. Measure
                    // using WRAP_CONTENT so that we can find out the view's
                    // optimal height. We'll restore the original height of 0
                    // after measurement.
                    lp.heightMode = .wrapContent
                }
                
                // Determine how big this child would like to be. If this or
                // previous children have given a weight, then we allow it to
                // use all available space (and we will shrink things later
                // if needed).
                let usedHeight = totalWeight.isZero ? self.totalLength : 0
                measureChildBeforeLayout(child, childIndex: measureIdx0, widthMeasureSpec: widthMeasureSpec, totalWidth: 0, heightMeasureSpec: heightMeasureSpec, totalHeight: usedHeight)
                
                let childHeight = lp.measuredHeight
                if (useExcessSpace) {
                    // Restore the original height and record how much space
                    // we've allocated to excess-only children so that we can
                    // match the behavior of EXACTLY measurement.
                    lp.heightDimension = 0
                    consumedExcessSpace += childHeight
                }
                
                let total = self.totalLength
                self.totalLength = max(total, total + childHeight + lp.marginTop + lp.marginBottom + getNextLocationOffset(child))
                
                if (useLargestChild) {
                    largestChildHeight = max(childHeight, largestChildHeight)
                }
            }
            
            /**
             * If applicable, compute the additional offset to the child's baseline
             * we'll need later when asked [.getBaseline].
             */
            if (baselineChildIndex >= 0 && baselineChildIndex == measureIdx0 + 1) {
                baselineChildTop = totalLength
            }
            
            // if we are trying to use a child index for our baseline, the above
            // book keeping only works if there are no children above it with
            // weight.  fail fast to aid the developer.
            if (measureIdx0 < baselineChildIndex && lp.weight > 0) {
                fatalError("A child of LinearLayout with index "
                    + "less than mBaselineAlignedChildIndex has weight > 0, which "
                    + "won't work.  Either remove the weight, or don't set "
                    + "mBaselineAlignedChildIndex.")
            }
            
            var matchWidthLocally = false
            if (widthSpec != .exactly && lp.widthMode == .matchParent) {
                // The width of the linear layout will scale, and at least one
                // child said it wanted to match our width. Set a flag
                // indicating that we need to remeasure at least that view when
                // we know our width.
                matchWidth = true
                matchWidthLocally = true
            }
            
            let margin = lp.marginAbsLeft + lp.marginAbsRight
            let measuredWidth = lp.measuredWidth + margin
            maxWidth = max(maxWidth, measuredWidth)
            childState = ALSBaseLayout.combineMeasuredStates(childState, widthMode: lp.measuredWidthSpec, heightMode: lp.measuredHeightSpec)
            
            allFillParent = allFillParent && lp.widthMode == .matchParent
            if (lp.weight > 0) {
                /*
                 * Widths of weighted Views are bogus if we end up
                 * remeasuring, so keep them separate.
                 */
                weightedMaxWidth = max(weightedMaxWidth, matchWidthLocally ? margin : measuredWidth)
            } else {
                alternativeMaxWidth = max(alternativeMaxWidth, matchWidthLocally ? margin : measuredWidth)
            }
            
            measureIdx0 += getChildrenSkipCount(child, index: measureIdx0) + 1 // combined with measureIdx0++
        }
        
        if (totalLength > 0 && hasDividerBeforeChildAt(count)) {
            totalLength += dividerSize.height
        }
        
        if (useLargestChild && (heightSpec == .atMost || heightSpec == .unspecified)) {
            totalLength = 0
            
            var measureIdx1: Int = 0
            while (measureIdx1 < count) {
                guard let child = getVirtualChildAt(measureIdx1) else {
                    self.totalLength += measureNullChild(measureIdx1)
                    measureIdx1 += measureIdx1
                    continue
                }
                
                let lp = child.layoutParams
                
                if (lp.hidden) {
                    measureIdx1 += getChildrenSkipCount(child, index: measureIdx1) + 1 // combined with measureIdx00++
                    continue
                }
                // Account for negative margins
                let totalLength = self.totalLength
                self.totalLength = max(totalLength, totalLength + largestChildHeight + lp.marginTop + lp.marginBottom + getNextLocationOffset(child))
                measureIdx1 += 1
            }
        }
        
        // Add in our padding
        totalLength += actualLayoutMargins.top + actualLayoutMargins.bottom
        
        var heightSize = totalLength
        
        // Check against our minimum height
        let suggestedMinimumHeight: CGFloat = 0
        heightSize = max(heightSize, suggestedMinimumHeight)
        
        // Reconcile our calculated size with the heightMeasureSpec
        let heightSizeAndState: ALSLayoutParams.MeasureSpec = ALSBaseLayout.resolveSizeAndState(heightSize, measureSpec: heightMeasureSpec, childMeasuredState: .unspecified)
        heightSize = heightSizeAndState.0
        
        // Either expand children with weight to take up available space or
        // shrink them if they extend beyond our current bounds. If we skipped
        // measurement on any children, we need to measure them now.
        var remainingExcess = heightSize - totalLength + consumedExcessSpace
        if (skippedMeasure || remainingExcess != 0 && totalWeight > 0) {
            var remainingWeightSum = weightSum > 0 ? weightSum : totalWeight
            
            totalLength = 0
            
            for i in 0..<count {
                guard let child = getVirtualChildAt(i) else {
                    continue
                }
                let lp = child.layoutParams
                if (lp.hidden) {
                    continue
                }
                
                let childWeight = lp.weight
                if (childWeight > 0) {
                    let share = (childWeight * remainingExcess / remainingWeightSum)
                    remainingExcess -= share
                    remainingWeightSum -= childWeight
                    
                    let childHeight: CGFloat
                    if (self.measureWithLargestChild && heightSpec != .exactly) {
                        childHeight = largestChildHeight
                    } else if (lp.heightDimension == 0) {
                        // This child needs to be laid out from scratch using
                        // only its share of excess space.
                        childHeight = share
                    } else {
                        // This child had some intrinsic height to which we
                        // need to add its share of excess space.
                        childHeight = lp.measuredHeight + share
                    }
                    
                    let childHeightMeasureSpec: ALSLayoutParams.MeasureSpec = (max(0, childHeight), .exactly)
                    let childWidthMeasureSpec = ALSBaseLayout.getChildMeasureSpec(widthMeasureSpec, padding: actualLayoutMargins.left + actualLayoutMargins.right + lp.marginAbsLeft + lp.marginAbsRight, childDimension: lp.widthDimension, childDimensionMode: lp.widthMode)
                    
                    lp.measure(child, widthSpec: childWidthMeasureSpec, heightSpec: childHeightMeasureSpec)
                    
                    // Child may now not fit in vertical dimension.
                    childState = ALSBaseLayout.combineMeasuredStates(childState, widthMode: .unspecified, heightMode: lp.measuredHeightSpec)
                }
                
                let margin = lp.marginAbsLeft + lp.marginAbsRight
                let measuredWidth = lp.measuredWidth + margin
                maxWidth = max(maxWidth, measuredWidth)
                
                let matchWidthLocally = widthSpec != .exactly && lp.widthMode == .matchParent
                
                alternativeMaxWidth = max(alternativeMaxWidth, matchWidthLocally ? margin : measuredWidth)
                
                allFillParent = allFillParent && lp.widthMode == .matchParent
                
                let totalLength = self.totalLength
                self.totalLength = max(totalLength, totalLength + lp.measuredHeight + lp.marginTop + lp.marginBottom + getNextLocationOffset(child))
            }
            
            // Add in our padding
            totalLength += actualLayoutMargins.top + actualLayoutMargins.bottom
            // TODO: Should we recompute the heightSpec based on the new total length?
        } else {
            alternativeMaxWidth = max(alternativeMaxWidth, weightedMaxWidth)
            
            
            // We have no limit, so make all weighted views as tall as the largest child.
            // Children will have already been measured once.
            if (useLargestChild && heightSpec != .exactly) {
                for i in 0..<count {
                    guard let child = getVirtualChildAt(i) , !child.layoutHidden else {
                        continue
                    }
                    let lp = child.layoutParams
                    
                    let childExtra = lp.weight
                    if (childExtra > 0) {
                        lp.measure(child, widthSpec: (lp.measuredWidth, .exactly), heightSpec: (largestChildHeight, .exactly))
                    }
                }
            }
        }
        
        if (!allFillParent && widthSpec != .exactly) {
            maxWidth = alternativeMaxWidth
        }
        
        maxWidth += actualLayoutMargins.left + actualLayoutMargins.right
        
        // Check against our minimum width
        let suggestedMinimumWidth: CGFloat = 0
        maxWidth = max(maxWidth, suggestedMinimumWidth)
        
        let finalSize = ALSBaseLayout.resolveSizeAndState(maxWidth, measureSpec: widthMeasureSpec, childMeasuredState: childState.0)
        
        if (matchWidth) {
            forceUniformWidth(count, heightMeasureSpec: heightMeasureSpec)
        }
        
        let heightMode: ALSLayoutParams.SizeMode = layoutParamsOrNull?.heightMode ?? self.heightMode
        
        if (heightMode == .wrapContent) {
            return CGSize(width: finalSize.0, height: self.totalLength)
        } else {
            return CGSize(width: finalSize.0, height: heightSizeAndState.0)
        }
    }
    
    internal func measureHorizontal(_ widthMeasureSpec: ALSLayoutParams.MeasureSpec, _ heightMeasureSpec: ALSLayoutParams.MeasureSpec) -> CGSize {
        totalLength = 0
        var maxHeight: CGFloat = 0
        var childState: ALSLayoutParams.MeasureStates = (.unspecified, .unspecified)
        var alternativeMaxHeight: CGFloat = 0
        var weightedMaxHeight: CGFloat = 0
        var allFillParent = true
        var totalWeight: CGFloat = 0
        
        let count = virtualChildCount
        
        let widthSpec = widthMeasureSpec.1
        let heightSpec = heightMeasureSpec.1
        
        var matchHeight = false
        var skippedMeasure = false
        
        if (self.maxAscent == nil || self.maxDescent == nil) {
            self.maxAscent = [CGFloat](repeating: CGFloat.nan, count: ALSLinearLayout.VERTICAL_GRAVITY_COUNT)
            self.maxDescent = [CGFloat](repeating: CGFloat.nan, count: ALSLinearLayout.VERTICAL_GRAVITY_COUNT)
        }
        
        var maxAscent = self.maxAscent!
        var maxDescent = self.maxDescent!
        
        for i in 0..<ALSLinearLayout.VERTICAL_GRAVITY_COUNT {
            maxAscent[i] = CGFloat.nan
            maxDescent[i] = CGFloat.nan
        }
        
        let baselineAligned = self.baselineAligned
        let useLargestChild = self.measureWithLargestChild
        
        let isExactly = widthSpec == .exactly
        
        var largestChildWidth: CGFloat = CGFloat.leastNormalMagnitude
        var usedExcessSpace: CGFloat = 0
        
        let layoutDirection = self.layoutDirection
        
        // See how wide everyone is. Also remember max height.
        
        var measureIdx0: Int = 0
        while (measureIdx0 < count) {
            guard let child = getVirtualChildAt(measureIdx0) else {
                totalLength += measureNullChild(measureIdx0)
                measureIdx0 += 1
                continue
            }
            let lp = child.layoutParams
            
            lp.resolveLayoutDirection(layoutDirection)
            
            if (lp.hidden) {
                measureIdx0 += getChildrenSkipCount(child, index: measureIdx0) + 1 // combined with measureIdx0++
                continue
            }
            
            if (hasDividerBeforeChildAt(measureIdx0)) {
                totalLength += dividerSize.width
            }
            
            
            totalWeight += lp.weight
            
            let useExcessSpace = lp.widthDimension == 0 && lp.weight > 0
            if (widthSpec == .exactly && useExcessSpace) {
                // Optimization: don't bother measuring children who are only
                // laid out using excess space. These views will get measured
                // later if we have space to distribute.
                if (isExactly) {
                    self.totalLength += lp.marginAbsLeft + lp.marginAbsRight
                } else {
                    let total = self.totalLength
                    self.totalLength = max(total, total + lp.marginAbsLeft + lp.marginAbsRight)
                }
                
                // Baseline alignment requires to measure widgets to obtain the
                // baseline offset (in particular for TextViews). The following
                // defeats the optimization mentioned above. Allow the child to
                // use as much space as it wants because we can shrink things
                // later (and re-measure).
                if (baselineAligned) {
                    let freeWidthSpec: ALSLayoutParams.MeasureSpec = (widthMeasureSpec.0, .unspecified)
                    let freeHeightSpec: ALSLayoutParams.MeasureSpec = (heightMeasureSpec.0, .unspecified)
                    lp.measure(child, widthSpec: freeWidthSpec, heightSpec: freeHeightSpec)
                } else {
                    skippedMeasure = true
                }
            } else {
                if (useExcessSpace) {
                    // The widthMode is either UNSPECIFIED or AT_MOST, and
                    // this child is only laid out using excess space. Measure
                    // using WRAP_CONTENT so that we can find out the view's
                    // optimal width. We'll restore the original width of 0
                    // after measurement.
                    lp.widthMode = .wrapContent
                }
                
                // Determine how big this child would like to be. If this or
                // previous children have given a weight, then we allow it to
                // use all available space (and we will shrink things later
                // if needed).
                let usedWidth = totalWeight.isZero ? totalLength : 0
                measureChildBeforeLayout(child, childIndex: measureIdx0, widthMeasureSpec: widthMeasureSpec, totalWidth: usedWidth, heightMeasureSpec: heightMeasureSpec, totalHeight: 0)
                
                let childWidth = lp.measuredWidth
                if (useExcessSpace) {
                    // Restore the original width and record how much space
                    // we've allocated to excess-only children so that we can
                    // match the behavior of EXACTLY measurement.
                    lp.widthDimension = 0
                    usedExcessSpace += childWidth
                }
                
                if (isExactly) {
                    totalLength += childWidth + lp.marginAbsLeft + lp.marginAbsRight + getNextLocationOffset(child)
                } else {
                    let total = self.totalLength
                    self.totalLength = max(total, total + childWidth + lp.marginAbsLeft + lp.marginAbsRight + getNextLocationOffset(child))
                }
                
                if (useLargestChild) {
                    largestChildWidth = max(childWidth, largestChildWidth)
                }
            }
            
            var matchHeightLocally = false
            if (heightSpec != .exactly && lp.heightMode == .matchParent) {
                // The height of the linear layout will scale, and at least one
                // child said it wanted to match our height. Set a flag indicating that
                // we need to remeasure at least that view when we know our height.
                matchHeight = true
                matchHeightLocally = true
            }
            
            let margin = lp.marginTop + lp.marginBottom
            let childHeight = lp.measuredHeight + margin
            childState = ALSBaseLayout.combineMeasuredStates(childState, widthMode: lp.measuredWidthSpec, heightMode: lp.measuredHeightSpec)
            
            if (baselineAligned) {
                let childBaseline = child.baselineBottomValue
                if (childBaseline != -1) {
                    // Translates the child's vertical gravity into an index
                    // in the range 0..VERTICAL_GRAVITY_COUNT
                    let gravity = (lp.gravity < 0 ? self.gravity : lp.gravity) & ALSGravity.VERTICAL_GRAVITY_MASK
                    let index = gravity >> ALSGravity.AXIS_Y_SHIFT & ~ALSGravity.AXIS_SPECIFIED >> 1
                    
                    maxAscent[index] = max(maxAscent[index], childBaseline)
                    maxDescent[index] = max(maxDescent[index], childHeight - childBaseline)
                }
            }
            
            maxHeight = max(maxHeight, childHeight)
            
            allFillParent = allFillParent && lp.heightMode == .matchParent
            if (lp.weight > 0) {
                /*
                 * Heights of weighted Views are bogus if we end up
                 * remeasuring, so keep them separate.
                 */
                weightedMaxHeight = max(weightedMaxHeight, matchHeightLocally ? margin : childHeight)
            } else {
                alternativeMaxHeight = max(alternativeMaxHeight, matchHeightLocally ? margin : childHeight)
            }
            
            measureIdx0 += getChildrenSkipCount(child, index: measureIdx0) + 1 // combined with measureIdx0++
        }
        
        if (totalLength > 0 && hasDividerBeforeChildAt(count)) {
            totalLength += dividerSize.width
        }
        
        // Check mMaxAscent[INDEX_TOP] first because it maps to Gravity.TOP,
        // the most common case
        if (maxAscent[ALSLinearLayout.INDEX_TOP] != -1 || maxAscent[ALSLinearLayout.INDEX_CENTER_VERTICAL] != -1 || maxAscent[ALSLinearLayout.INDEX_BOTTOM] != -1 || maxAscent[ALSLinearLayout.INDEX_FILL] != -1) {
            let ascent = max(maxAscent[ALSLinearLayout.INDEX_FILL], max(maxAscent[ALSLinearLayout.INDEX_CENTER_VERTICAL], max(maxAscent[ALSLinearLayout.INDEX_TOP], maxAscent[ALSLinearLayout.INDEX_BOTTOM])))
            let descent = max(maxDescent[ALSLinearLayout.INDEX_FILL], max(maxDescent[ALSLinearLayout.INDEX_CENTER_VERTICAL], max(maxDescent[ALSLinearLayout.INDEX_TOP], maxDescent[ALSLinearLayout.INDEX_BOTTOM])))
            maxHeight = max(maxHeight, ascent + descent)
        }
        
        if (useLargestChild && (widthSpec == .atMost || widthSpec == .unspecified)) {
            totalLength = 0
            
            var measureIdx1: Int = 0
            while (measureIdx1 < count) {
                guard let child = getVirtualChildAt(measureIdx1) else {
                    totalLength += measureNullChild(measureIdx1)
                    measureIdx1 += 1
                    continue
                }
                
                let lp = child.layoutParams
                
                if (lp.hidden) {
                    measureIdx1 += getChildrenSkipCount(child, index: measureIdx1) + 1 // combined with measureIdx1++
                    continue
                }
                
                if (isExactly) {
                    self.totalLength += largestChildWidth + lp.marginAbsLeft + lp.marginAbsRight + getNextLocationOffset(child)
                } else {
                    let total = self.totalLength
                    self.totalLength = max(total, total + largestChildWidth + lp.marginAbsLeft + lp.marginAbsRight + getNextLocationOffset(child))
                }
                measureIdx1 += 1
            }
        }
        
        // Add in our padding
        totalLength += actualLayoutMargins.left + actualLayoutMargins.right
        
        var widthSize = totalLength
        
        // Check against our minimum width
        let suggestedMinimumWidth: CGFloat = 0
        widthSize = max(widthSize, suggestedMinimumWidth)
        
        // Reconcile our calculated size with the widthMeasureSpec
        let widthSizeAndState = ALSBaseLayout.resolveSizeAndState(widthSize, measureSpec: widthMeasureSpec, childMeasuredState: .unspecified)
        widthSize = widthSizeAndState.0
        
        // Either expand children with weight to take up available space or
        // shrink them if they extend beyond our current bounds. If we skipped
        // measurement on any children, we need to measure them now.
        var remainingExcess = widthSize - totalLength + usedExcessSpace
        if (skippedMeasure || !remainingExcess.isZero && totalWeight > 0) {
            var remainingWeightSum = weightSum > 0 ? weightSum : totalWeight
            
            for i in 0..<ALSLinearLayout.VERTICAL_GRAVITY_COUNT {
                maxAscent[i] = CGFloat.nan
                maxDescent[i] = CGFloat.nan
            }
            
            maxHeight = -1
            
            totalLength = 0
            
            for i in 0..<count {
                guard let child = getVirtualChildAt(i) , !child.layoutHidden else {
                    continue
                }
                
                let lp = child.layoutParams
                let childWeight = lp.weight
                if (childWeight > 0) {
                    let share = childWeight * remainingExcess / remainingWeightSum
                    remainingExcess -= share
                    remainingWeightSum -= childWeight
                    
                    let childWidth: CGFloat
                    if (self.measureWithLargestChild && widthSpec != .exactly) {
                        childWidth = largestChildWidth
                    } else if (lp.widthDimension == 0) {
                        // This child needs to be laid out from scratch using
                        // only its share of excess space.
                        childWidth = share
                    } else {
                        // This child had some intrinsic width to which we
                        // need to add its share of excess space.
                        childWidth = lp.measuredWidth + share
                    }
                    
                    let childWidthMeasureSpec: ALSLayoutParams.MeasureSpec = (max(0, childWidth), .exactly)
                    let childHeightMeasureSpec = ALSBaseLayout.getChildMeasureSpec(heightMeasureSpec, padding: actualLayoutMargins.top + actualLayoutMargins.bottom + lp.marginTop + lp.marginBottom, childDimension: lp.heightDimension, childDimensionMode: lp.heightMode)
                    lp.measure(child, widthSpec: childWidthMeasureSpec, heightSpec: childHeightMeasureSpec)
                    
                    // Child may now not fit in horizontal dimension.
                    childState = ALSBaseLayout.combineMeasuredStates(childState, widthMode: lp.measuredWidthSpec, heightMode: .unspecified)
                }
                
                if (isExactly) {
                    totalLength += lp.measuredWidth + lp.marginAbsLeft + lp.marginAbsRight +
                        getNextLocationOffset(child)
                } else {
                    let total = self.totalLength
                    self.totalLength = max(total, total + lp.measuredWidth + lp.marginAbsLeft + lp.marginAbsRight + getNextLocationOffset(child))
                }
                
                let matchHeightLocally = heightSpec != .exactly && lp.heightMode == .matchParent
                
                let margin = lp.marginTop + lp.marginBottom
                let childHeight = lp.measuredHeight + margin
                maxHeight = max(maxHeight, childHeight)
                alternativeMaxHeight = max(alternativeMaxHeight, matchHeightLocally ? margin : childHeight)
                
                allFillParent = allFillParent && lp.heightMode == .matchParent
                
                if (baselineAligned) {
                    let childBaseline = child.baselineBottomValue
                    if (childBaseline != -1) {
                        // Translates the child's vertical gravity into an index in the range 0..2
                        let gravity = (lp.gravity < 0 ? self.gravity : lp.gravity) & ALSGravity.VERTICAL_GRAVITY_MASK
                        let index = gravity >> ALSGravity.AXIS_Y_SHIFT & ~ALSGravity.AXIS_SPECIFIED >> 1
                        
                        maxAscent[index] = max(maxAscent[index], childBaseline)
                        maxDescent[index] = max(maxDescent[index], childHeight - childBaseline)
                    }
                }
            }
            
            // Add in our padding
            totalLength += actualLayoutMargins.left + actualLayoutMargins.right
            // TODO: Should we update widthSize with the new total length?
            
            // Check mMaxAscent[INDEX_TOP] first because it maps to Gravity.TOP,
            // the most common case
            if (maxAscent[ALSLinearLayout.INDEX_TOP] != -1 || maxAscent[ALSLinearLayout.INDEX_CENTER_VERTICAL] != -1 || maxAscent[ALSLinearLayout.INDEX_BOTTOM] != -1 || maxAscent[ALSLinearLayout.INDEX_FILL] != -1) {
                let ascent = max(maxAscent[ALSLinearLayout.INDEX_FILL], max(maxAscent[ALSLinearLayout.INDEX_CENTER_VERTICAL], max(maxAscent[ALSLinearLayout.INDEX_TOP], maxAscent[ALSLinearLayout.INDEX_BOTTOM])))
                let descent = max(maxDescent[ALSLinearLayout.INDEX_FILL], max(maxDescent[ALSLinearLayout.INDEX_CENTER_VERTICAL], max(maxDescent[ALSLinearLayout.INDEX_TOP], maxDescent[ALSLinearLayout.INDEX_BOTTOM])))
                maxHeight = max(maxHeight, ascent + descent)
            }
        } else {
            alternativeMaxHeight = max(alternativeMaxHeight, weightedMaxHeight)
            
            // We have no limit, so make all weighted views as wide as the largest child.
            // Children will have already been measured once.
            if (useLargestChild && widthSpec != .exactly) {
                for i in 0..<count {
                    guard let child = getVirtualChildAt(i) , !child.layoutHidden else {
                        continue
                    }
                    
                    let lp = child.layoutParams
                    
                    let childExtra = lp.weight
                    if (childExtra > 0) {
                        lp.measure(child, widthSpec: (largestChildWidth, .exactly), heightSpec: (lp.measuredHeight, .exactly))
                    }
                }
            }
        }
        
        if (!allFillParent && heightSpec != .exactly) {
            maxHeight = alternativeMaxHeight
        }
        
        maxHeight += actualLayoutMargins.top + actualLayoutMargins.bottom
        
        // Check against our minimum height
        let suggestedMinimumHeight: CGFloat = 0
        maxHeight = max(maxHeight, suggestedMinimumHeight)
        
        let finalSize = ALSBaseLayout.resolveSizeAndState(maxHeight, measureSpec: heightMeasureSpec, childMeasuredState: childState.1)
        if (matchHeight) {
            forceUniformHeight(count, widthMeasureSpec: widthMeasureSpec)
        }
        
        
        let widthMode: ALSLayoutParams.SizeMode = layoutParamsOrNull?.widthMode ?? self.widthMode
        
        if (widthMode == .wrapContent) {
            return CGSize(width: self.totalLength, height: finalSize.0)
        } else {
            return CGSize(width: widthSizeAndState.0, height: finalSize.0)
        }
    }
    
    
    
    /**
     * Position the children during a layout pass if the orientation of this
     * LinearLayout is set to [Orientation.VERTICAL].
     
     * @param left
     * *
     * @param top
     * *
     * @param right
     * *
     * @param bottom
     * *
     * @see .orientation
     
     * @see .onLayout
     */
    internal func layoutVertical(_ frame: CGRect) {
        
        let layoutDirection = self.layoutDirection
        let paddingLeft = actualLayoutMargins.left
        
        var childTop: CGFloat
        var childLeft: CGFloat
        
        // Where right end of child should go
        let width = frame.right - frame.left
        let childRight = width - actualLayoutMargins.right
        
        // Space available for child
        let childSpace = width - paddingLeft - actualLayoutMargins.right
        
        let count = virtualChildCount
        
        let majorGravity = gravity & ALSGravity.VERTICAL_GRAVITY_MASK
        let minorGravity = gravity & ALSGravity.RELATIVE_HORIZONTAL_GRAVITY_MASK
        
        switch (majorGravity) {
        case ALSGravity.BOTTOM:
            // mTotalLength contains the padding already
            childTop = actualLayoutMargins.top + frame.bottom - frame.top - totalLength
        // mTotalLength contains the padding already
        case ALSGravity.CENTER_VERTICAL:
            childTop = actualLayoutMargins.top + (frame.bottom - frame.top - totalLength) / 2
        default:
            childTop = actualLayoutMargins.top
        }
        
        var layoutIdx0: Int = 0
        while (layoutIdx0 < count) {
            guard let child = getVirtualChildAt(layoutIdx0) else {
                childTop += measureNullChild(layoutIdx0)
                layoutIdx0 += 1
                continue
            }
            
            let lp = child.layoutParams
            
            if (!lp.hidden) {
                let childWidth = lp.measuredWidth
                let childHeight = lp.measuredHeight
                
                var gravity = lp.gravity
                if (gravity < 0) {
                    gravity = minorGravity
                }
                let absoluteGravity = ALSGravity.getAbsoluteGravity(gravity, layoutDirection: layoutDirection)
                switch (absoluteGravity & ALSGravity.HORIZONTAL_GRAVITY_MASK) {
                case ALSGravity.CENTER_HORIZONTAL:
                    childLeft = paddingLeft + (childSpace - childWidth) / 2 + lp.marginAbsLeft - lp.marginAbsRight
                case ALSGravity.RIGHT:
                    childLeft = childRight - childWidth - lp.marginAbsRight
                default:
                    childLeft = paddingLeft + lp.marginAbsLeft
                }
                
                if (hasDividerBeforeChildAt(layoutIdx0)) {
                    childTop += dividerSize.height
                }
                
                childTop += lp.marginTop
                child.frame = CGRect(x: childLeft, y: childTop + getLocationOffset(child), width: childWidth, height: childHeight)
                childTop += childHeight + lp.marginBottom + getNextLocationOffset(child)
                
                layoutIdx0 += getChildrenSkipCount(child, index: layoutIdx0)
            } else {
                child.frame = CGRect.zero
            }
            layoutIdx0 += 1
        }
    }
    
    /**
     * Position the children during a layout pass if the orientation of this
     * LinearLayout is set to [Orientation.HORIZONTAL].
     
     * @param left
     * *
     * @param top
     * *
     * @param right
     * *
     * @param bottom
     * *
     * @see .orientation
     
     * @see .onLayout
     */
    internal func layoutHorizontal(_ frame: CGRect) {
        let layoutDirection = self.layoutDirection
        let isLayoutRtl = layoutDirection == .rightToLeft
        
        let paddingTop = actualLayoutMargins.top
        
        var childTop: CGFloat
        var childLeft: CGFloat
        
        // Where bottom of child should go
        let height = frame.height
        let childBottom = height - actualLayoutMargins.bottom
        
        // Space available for child
        let childSpace = height - paddingTop - actualLayoutMargins.bottom
        
        let count = virtualChildCount
        
        let majorGravity = gravity & ALSGravity.RELATIVE_HORIZONTAL_GRAVITY_MASK
        let minorGravity = gravity & ALSGravity.VERTICAL_GRAVITY_MASK
        
        let baselineAligned = self.baselineAligned
        
        let maxAscent = self.maxAscent!
        let maxDescent = self.maxDescent!
        
        
        switch (ALSGravity.getAbsoluteGravity(majorGravity, layoutDirection: layoutDirection)) {
        case ALSGravity.RIGHT:
            // mTotalLength contains the padding already
            childLeft = actualLayoutMargins.left + frame.right - frame.left - totalLength
        case ALSGravity.CENTER_HORIZONTAL:
            // mTotalLength contains the padding already
            childLeft = actualLayoutMargins.left + (frame.right - frame.left - totalLength) / 2
        default:
            childLeft = actualLayoutMargins.left
        }
        
        var start = 0
        var dir = 1
        //In case of RTL, start drawing from the last child.
        if (isLayoutRtl) {
            start = count - 1
            dir = -1
        }
        
        var layoutIdx0: Int = 0
        while (layoutIdx0 < count) {
            let childIndex = start + dir * layoutIdx0
            guard let child = getVirtualChildAt(childIndex) else {
                childLeft += measureNullChild(childIndex)
                layoutIdx0 += 1
                continue
            }
            
            let lp = child.layoutParams
            
            if (!lp.hidden) {
                let childWidth = lp.measuredWidth
                let childHeight = lp.measuredHeight
                var childBaseline: CGFloat = CGFloat.nan
                
                if (baselineAligned && lp.heightMode != .matchParent) {
                    childBaseline = child.baselineBottomValue
                }
                
                var gravity = lp.gravity
                if (gravity < 0) {
                    gravity = minorGravity
                }
                
                switch (gravity & ALSGravity.VERTICAL_GRAVITY_MASK) {
                case ALSGravity.TOP:
                    childTop = paddingTop + lp.marginTop
                    if (!childBaseline.isNaN) {
                        childTop += maxAscent[ALSLinearLayout.INDEX_TOP] - childBaseline
                    }
                case ALSGravity.CENTER_VERTICAL:
                    // Removed support for baseline alignment when layout_gravity or
                    // gravity == center_vertical. See bug #1038483.
                    // Keep the code around if we need to re-enable this feature
                    // if (childBaseline != -1) {
                    //     // Align baselines vertically only if the child is smaller than us
                    //     if (childSpace - childHeight > 0) {
                    //         childTop = paddingTop + (childSpace / 2) - childBaseline;
                    //     } else {
                    //         childTop = paddingTop + (childSpace - childHeight) / 2;
                    //     }
                    // } else {
                    childTop = paddingTop + (childSpace - childHeight) / 2 + lp.marginTop - lp.marginBottom
                case ALSGravity.BOTTOM:
                    childTop = childBottom - childHeight - lp.marginBottom
                    if (childBaseline != -1) {
                        let descent = lp.measuredHeight - childBaseline
                        childTop -= maxDescent[ALSLinearLayout.INDEX_BOTTOM] - descent
                    }
                default:
                    childTop = paddingTop
                }
                
                if (hasDividerBeforeChildAt(childIndex)) {
                    childLeft += dividerSize.width
                }
                
                childLeft += lp.marginAbsLeft
                child.frame = CGRect(x: childLeft + getLocationOffset(child), y: childTop, width: childWidth, height: childHeight)
                childLeft += childWidth + lp.marginAbsRight + getNextLocationOffset(child)
                
                layoutIdx0 += getChildrenSkipCount(child, index: childIndex)
            } else {
                child.frame = CGRect.zero
            }
            layoutIdx0 += 1
        }
    }
    
    
    internal func drawHorizontalDivider(_ top: CGFloat) {
        let left = bounds.left + actualLayoutMargins.left + dividerPadding
        let right = bounds.right - actualLayoutMargins.right - dividerPadding
        let rect = CGRect(x: left, y: top, width: right - left , height: dividerSize.height)
        divider.draw(in: rect)
    }
    
    internal func drawVerticalDivider(_ left: CGFloat) {
        let top = bounds.top + actualLayoutMargins.top + dividerPadding
        let bottom = bounds.bottom - actualLayoutMargins.bottom - dividerPadding
        let rect = CGRect(x: left, y: top, width: dividerSize.width, height: bottom - top)
        divider.draw(in: rect)
    }
    
    internal func getVirtualChildAt(_ index: Int) -> UIView! {
        return subviews[index]
    }
    
    internal var virtualChildCount: Int {
        return subviews.count
    }
    
    /**
     * Determines where to position dividers between children.
     
     * @param childIndex Index of child to check for preceding divider
     * *
     * @return true if there should be a divider before the child at childIndex
     * *
     * @hide Pending API consideration. Currently only used internally by the system.
     */
    internal func hasDividerBeforeChildAt(_ childIndex: Int) -> Bool {
        if (childIndex == virtualChildCount) {
            // Check whether the end divider should draw.
            return showDividers.contains(.End)
        }
        
        if (allViewsAreGoneBefore(childIndex)) {
            // This is the first view that's not gone, check if beginning divider is enabled.
            return showDividers.contains(.Beginning)
        } else {
            return showDividers.contains(.Middle)
        }
    }
    
    /**
     * Checks whether all (virtual) child views before the given index are gone.
     */
    fileprivate func allViewsAreGoneBefore(_ childIndex: Int) -> Bool {
        for i in (0..<childIndex).reversed() {
            if let child = getVirtualChildAt(i) , !child.layoutHidden {
                return false
            }
        }
        return true
    }
    
    
    /**
     *
     * Returns the size (width or height) that should be occupied by a null
     * child.
     
     * @param childIndex the index of the null child
     * *
     * @return the width or height of the child depending on the orientation
     */
    internal func measureNullChild(_ childIndex: Int) -> CGFloat {
        return 0
    }
    
    /**
     *
     * Measure the child according to the parent's measure specs. This
     * method should be overriden by subclasses to force the sizing of
     * children. This method is called by [.measureVertical] and
     * [.measureHorizontal].
     
     * @param child             the child to measure
     * *
     * @param childIndex        the index of the child in this view
     * *
     * @param widthMeasureSpec  horizontal space requirements as imposed by the parent
     * *
     * @param totalWidth        extra space that has been used up by the parent horizontally
     * *
     * @param heightMeasureSpec vertical space requirements as imposed by the parent
     * *
     * @param totalHeight       extra space that has been used up by the parent vertically
     */
    internal func measureChildBeforeLayout(_ child: UIView, childIndex: Int, widthMeasureSpec: ALSLayoutParams.MeasureSpec, totalWidth: CGFloat, heightMeasureSpec: ALSLayoutParams.MeasureSpec, totalHeight: CGFloat) {
        measureChildWithMargins(child, parentWidthMeasureSpec: widthMeasureSpec, widthUsed: totalWidth, parentHeightMeasureSpec: heightMeasureSpec, heightUsed: totalHeight)
    }
    
    
    /**
     *
     * Return the location offset of the specified child. This can be used
     * by subclasses to change the location of a given widget.
     
     * @param child the child for which to obtain the location offset
     * *
     * @return the location offset in points
     */
    internal func getLocationOffset(_ child: UIView)-> CGFloat {
        return 0
    }
    
    /**
     *
     * Return the size offset of the next sibling of the specified child.
     * This can be used by subclasses to change the location of the widget
     * following `child`.
     
     * @param child the child whose next sibling will be moved
     * *
     * @return the location offset of the next child in points
     */
    internal func getNextLocationOffset(_ child: UIView)-> CGFloat {
        return 0
    }
    
    /**
     *
     * Returns the number of children to skip after measuring/laying out
     * the specified child.
     
     * @param child the child after which we want to skip children
     * *
     * @param index the index of the child after which we want to skip children
     * *
     * @return the number of children to skip, 0 by default
     */
    internal func getChildrenSkipCount(_ child: UIView, index: Int) -> Int {
        return 0
    }
    
    fileprivate func forceUniformWidth(_ count: Int, heightMeasureSpec: ALSLayoutParams.MeasureSpec) {
        // Pretend that the linear layout has an exact size.
        let uniformMeasureSpec: ALSLayoutParams.MeasureSpec = (bounds.width, .exactly)
        for i in 0..<count {
            guard let child = getVirtualChildAt(i) , !child.layoutHidden else {
                continue
            }
            let lp = child.layoutParams
            
            if (lp.widthMode == .matchParent) {
                // Temporarily force children to reuse their old measured height
                // FIXME: this may not be right for something like wrapping text?
                let oldHeight = lp.heightDimension
                lp.heightDimension = lp.measuredHeight
                
                // Remeasue with new dimensions
                measureChildWithMargins(child, parentWidthMeasureSpec: uniformMeasureSpec, widthUsed: 0, parentHeightMeasureSpec: heightMeasureSpec, heightUsed: 0)
                lp.heightDimension = oldHeight
                
            }
        }
    }
    
    fileprivate func forceUniformHeight(_ count: Int, widthMeasureSpec: ALSLayoutParams.MeasureSpec) {
        // Pretend that the linear layout has an exact size. This is the measured height of
        // ourselves. The measured height should be the max height of the children, changed
        // to accommodate the heightMeasureSpec from the parent
        let uniformMeasureSpec: ALSLayoutParams.MeasureSpec = (bounds.height, .exactly)
        for i in 0..<count {
            guard let child = getVirtualChildAt(i) , !child.layoutHidden else {
                continue
            }
            let lp = child.layoutParams
            
            if (lp.heightMode == .matchParent) {
                // Temporarily force children to reuse their old measured width
                // FIXME: this may not be right for something like wrapping text?
                let oldWidth = lp.widthDimension
                lp.widthDimension = lp.measuredHeight
                
                // Remeasure with new dimensions
                measureChildWithMargins(child, parentWidthMeasureSpec: widthMeasureSpec, widthUsed: 0, parentHeightMeasureSpec: uniformMeasureSpec, heightUsed: 0)
                lp.widthDimension = oldWidth
                
            }
        }
    }
    
    
}
