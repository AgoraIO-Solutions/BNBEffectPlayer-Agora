//
//  UtilityAPIAdapter.swift
//  BanubaSdkApp
//
//  Created by Victor Privalov on 1/14/19.
//  Copyright © 2019 Banuba. All rights reserved.
//

import BanubaSdk
import BNBEffectPlayer

#if !targetEnvironment(simulator)

public final class UtilityAPIAdapter: UtilityAPIAdapting {
    public func setCallback(_ callback: @escaping UtilityLogCallback, for logLevel: UtilityLogLevel) {
        BNBUtilityManager.setLogRecordCallback({ (level, domain, message) in
            callback(level.logLevel, domain, message)
        }, level: logLevel.severityLevel)
    }
    public func setLogLevel(_ logLevel: UtilityLogLevel) {
        BNBUtilityManager.setLogLevel(logLevel.severityLevel)
    }
}

fileprivate extension UtilityLogLevel {
    var severityLevel: BNBSeverityLevel {
        get {
            switch self {
            case .debug:
                return .debug
            case .info:
                return .info
            case .warning:
                return .warning
            case .error:
                return .error
            }
        }
    }
}

fileprivate extension BNBSeverityLevel {
    var logLevel: UtilityLogLevel {
        get {
            switch self {
            case .debug:
                return .debug
            case .info:
                return .info
            case .warning:
                return .warning
            case .error:
                return .error
            }
        }
    }
}

#endif // !targetEnvironment(simulator)
