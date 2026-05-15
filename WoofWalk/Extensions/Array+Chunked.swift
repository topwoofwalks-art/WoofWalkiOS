import Foundation

extension Array {
    /// Splits the array into consecutive groups of at most `size` elements.
    /// Used to batch Firestore `whereIn` queries (max 10/30 ids per query) and
    /// to page through large lists for off-main-thread processing.
    ///
    /// Canonical single implementation — previously duplicated as both
    /// `fileprivate` and `internal` extensions in CommunityRepository.swift +
    /// UserRepository.swift, which Release-mode Swift correctly flagged as
    /// "invalid redeclaration" because the file-private guard didn't actually
    /// stop the symbol from clashing across the module's extension table.
    /// Centralised here 2026-05-15.
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
