//
//  ShowDividers+Stringify.swift
//  Pods
//
//  Created by Mariotaku Lee on 16/9/6.
//
//

import Foundation

extension ALSLinearLayout.ShowDividers {
    
    /**
     Init with raw value
     */
    internal init?(rawValue: String) {
        switch rawValue {
        case "None":
            self.rawValue = ALSLinearLayout.ShowDividers.None.rawValue
        case "Beginning":
            self.rawValue = ALSLinearLayout.ShowDividers.Beginning.rawValue
        case "Middle":
            self.rawValue = ALSLinearLayout.ShowDividers.Middle.rawValue
        case "End":
            self.rawValue = ALSLinearLayout.ShowDividers.End.rawValue
        default:
            return nil
        }
    }
    
    internal static func parse(_ str: String) -> ALSLinearLayout.ShowDividers {
        return str.components(separatedBy: "|").reduce(.None) { combined, optionString -> ALSLinearLayout.ShowDividers in
            return combined.union(ALSLinearLayout.ShowDividers(rawValue: optionString)!)
        }
    }
    
    internal var rawString: String {
        switch self {
        case ALSLinearLayout.ShowDividers.None:
            return "None"
        case ALSLinearLayout.ShowDividers.Beginning:
            return "Beginning"
        case ALSLinearLayout.ShowDividers.Middle:
            return "Middle"
        case ALSLinearLayout.ShowDividers.End:
            return "End"
        default:
            abort()
        }
    }
    
    
}
