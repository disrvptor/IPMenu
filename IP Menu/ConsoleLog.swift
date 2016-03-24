//
//  ConsoleLog.swift
//  IP Menu
//
//  Created by Guy Pascarella on 9/22/15.
//
//

import Foundation

class ConsoleLog {

    enum Level: String {
        case Debug = "DEBUG"
        case Info = "INFO"
        case Warning = "WARNING"
        case Error = "ERROR"
    }

    private static var currentLevel = Level.Info;

    static func getCurrentLevel() -> Level {
        return ConsoleLog.currentLevel;
    }

    static func setCurrentLevel(level: Level) {
        ConsoleLog.currentLevel = level;
    }

    static func debug(msg: String) {
        log(Level.Debug, msg: msg);
    }

    static func info(msg: String) {
        log(Level.Info, msg: msg);
    }

    static func warning(msg: String) {
        log(Level.Warning, msg: msg);
    }

    static func error(msg: String) {
        log(Level.Error, msg: msg);
    }

    static func log(level: Level, msg: String) {
        if ( ConsoleLog.isLevelEnabled(level) ) {
            // ISO 8601
            let date = NSDate()
            let formatter = NSDateFormatter()
            let enUSPosixLocale = NSLocale(localeIdentifier: "en_US_POSIX")
            formatter.locale = enUSPosixLocale
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
            print("[\(formatter.stringFromDate(date))] [\(level.rawValue)] \(msg)");
        }
    }

    static func isLevelEnabled(level: Level) -> Bool {
        switch (ConsoleLog.currentLevel) {
        case .Debug: return true;
        case .Info: return (level != .Debug);
        case .Warning: return (level != .Debug && level != .Info);
        case .Error: return (level == .Error)
        }
    }

}