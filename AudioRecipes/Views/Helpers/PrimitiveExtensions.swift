import Foundation

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}

extension Float {
    public func mappedExp(from source: ClosedRange<Float> = 0...1.0, to target: ClosedRange<Float> = 0...1.0) -> Float {
        
        var logStart2: Float = 0.0
        if target.lowerBound != 0 {
            logStart2 = Float.log(target.lowerBound);
        }
        
        let logStop2 = Float.log(target.upperBound);
        let scale = (logStop2-logStart2) / (source.upperBound-source.lowerBound);
        return Float.exp(logStart2 + scale*(self-source.lowerBound))
    }
    
    public func mappedExpInverted(from source: ClosedRange<Float> = 0...1.0, to target: ClosedRange<Float> = 0...1.0) -> Float {
        return target.upperBound - self.mappedExp(from: source, to: target) + target.lowerBound
    }
    
    /// Map the value to a new range
    /// Return a value on [from.lowerBound,from.upperBound] to a [to.lowerBound, to.upperBound] range
    ///
    /// - Parameters:
    ///   - from source: Current range (Default: 0...1.0)
    ///   - to target: Desired range (Default: 0...1.0)
    public func mapped(from source: ClosedRange<Float> = 0...1.0, to target: ClosedRange<Float> = 0...1.0) -> Float {
        return ((self - source.lowerBound) / (source.upperBound - source.lowerBound)) * (target.upperBound - target.lowerBound) + target.lowerBound
    }
    
    /// Map the value to a new inverted range
    /// Return a value on [from.lowerBound,from.upperBound] to the inverse of a [to.lowerBound, to.upperBound] range
    ///
    /// - Parameters:
    ///   - from source: Current range (Default: 0...1.0)
    ///   - to target: Desired range (Default: 0...1.0)
    public func mappedInverted(from source: ClosedRange<Float> = 0...1.0, to target: ClosedRange<Float> = 0...1.0) -> Float {
        return target.upperBound - self.mapped(from: source, to: target) + target.lowerBound
    }

    /// Map the value to a new range at a base-10 logarithmic scaling
    /// Return a value on [from.lowerBound,from.upperBound] to a [to.lowerBound, to.upperBound] range
    ///
    /// - Parameters:
    ///   - from source: Current range (Default: 0...1.0)
    ///   - to target: Desired range (Default: 0...1.0)
    public func mappedLog10(from source: ClosedRange<Float> = 0...1.0, to target: ClosedRange<Float> = 0...1.0) -> Float {
        let logN = Float.log10(self)
        
        var logStart1: Float = 0.0
        if source.lowerBound != 0 {
            logStart1 = Float.log10(source.lowerBound)
        }
        
        let logStop1 = Float.log10(source.upperBound)
        let result = ((logN - logStart1 ) / (logStop1 - logStart1)) * (target.upperBound - target.lowerBound) + target.lowerBound
        if result.isNaN {
            return 0.0
        } else {
            return ((logN - logStart1 ) / (logStop1 - logStart1)) * (target.upperBound - target.lowerBound) + target.lowerBound
        }
    }
}
