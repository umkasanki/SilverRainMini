import os

extension Logger {
    private static let subsystem = "local.oleg.SilverRainMini"

    static let app = Logger(subsystem: subsystem, category: "App")
    static let menuBar = Logger(subsystem: subsystem, category: "MenuBar")
    static let player = Logger(subsystem: subsystem, category: "Player")
}
