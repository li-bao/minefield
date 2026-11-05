import Foundation

/// 確定性可重現隨機數產生器 (基於 SplitMix64 演算法)
/// 符合 Swift 標準 RandomNumberGenerator 協定
public struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public let seed: UInt64

    public init(seed: UInt64) {
        self.seed = seed
        self.state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}
