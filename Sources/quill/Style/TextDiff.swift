import Foundation

/// One span of a word-level diff between two strings.
enum DiffOp: Equatable {
    case equal(String)
    case insert(String)
    case delete(String)
}

/// Word-level diff, the same idea as `git diff --word-diff` or Grammarly's
/// own before/after highlight — used to show what Auto Cleanup actually
/// changed before it types the result.
enum TextDiff {
    /// LCS-based diff over whitespace-separated words. O(n·m) time and
    /// space in word count, not character count — a single dictation is a
    /// few hundred words at most, so the DP table never gets large enough
    /// to matter. ponytail: would need a smarter (Myers) algorithm if this
    /// ever ran on multi-thousand-word documents; dictation never is.
    static func diff(before: String, after: String) -> [DiffOp] {
        let a = before.split(separator: " ").map(String.init)
        let b = after.split(separator: " ").map(String.init)
        let n = a.count, m = b.count
        guard n > 0 || m > 0 else { return [] }

        var lcs = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                lcs[i][j] = a[i] == b[j] ? lcs[i + 1][j + 1] + 1 : max(lcs[i + 1][j], lcs[i][j + 1])
            }
        }

        var ops: [DiffOp] = []
        var i = 0, j = 0
        while i < n && j < m {
            if a[i] == b[j] {
                ops.append(.equal(a[i]))
                i += 1; j += 1
            } else if lcs[i + 1][j] >= lcs[i][j + 1] {
                ops.append(.delete(a[i]))
                i += 1
            } else {
                ops.append(.insert(b[j]))
                j += 1
            }
        }
        while i < n { ops.append(.delete(a[i])); i += 1 }
        while j < m { ops.append(.insert(b[j])); j += 1 }
        return ops
    }
}

#if DEBUG
/// No test target wired up for this package — call `TextDiffSelfCheck.run()`
/// from anywhere reachable (a debugger breakpoint, a temporary print
/// statement at startup) to sanity-check the diff logic after touching it.
enum TextDiffSelfCheck {
    static func run() {
        let ops = TextDiff.diff(
            before: "I mostly look at educating and value through content",
            after: "I mostly focus on educating and conveying value through content"
        )
        let reconstructedBefore = ops.compactMap { op -> String? in
            switch op {
            case .equal(let w), .delete(let w): return w
            case .insert: return nil
            }
        }.joined(separator: " ")
        let reconstructedAfter = ops.compactMap { op -> String? in
            switch op {
            case .equal(let w), .insert(let w): return w
            case .delete: return nil
            }
        }.joined(separator: " ")
        assert(reconstructedBefore == "I mostly look at educating and value through content")
        assert(reconstructedAfter == "I mostly focus on educating and conveying value through content")
        assert(ops.contains(.delete("look")) && ops.contains(.insert("focus")))
        assert(TextDiff.diff(before: "same text", after: "same text").allSatisfy {
            if case .equal = $0 { return true } else { return false }
        })
    }
}
#endif
