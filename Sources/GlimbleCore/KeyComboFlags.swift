import CoreGraphics

public extension KeyCombo {
    /// The CoreGraphics modifier flags for this combo.
    var cgEventFlags: CGEventFlags {
        var flags: CGEventFlags = []
        for m in modifiers {
            switch m {
            case .command: flags.insert(.maskCommand)
            case .option:  flags.insert(.maskAlternate)
            case .control: flags.insert(.maskControl)
            case .shift:   flags.insert(.maskShift)
            }
        }
        return flags
    }
}
