//
//  LogBuffer.swift
//  containerr
//
//  Accumulates streamed log chunks while keeping memory bounded by trimming to
//  the most recent `maxCharacters`. Pure value type so it can be unit-tested
//  independently of the streaming Process.
//

import Foundation

struct LogBuffer: Equatable {
    private(set) var text = ""
    let maxCharacters: Int

    init(maxCharacters: Int = 200_000) {
        self.maxCharacters = maxCharacters
    }

    /// Appends a chunk, trimming the oldest output if the cap is exceeded.
    mutating func append(_ chunk: String) {
        text += chunk
        if text.count > maxCharacters {
            text = String(text.suffix(maxCharacters))
        }
    }

    mutating func clear() {
        text = ""
    }
}
