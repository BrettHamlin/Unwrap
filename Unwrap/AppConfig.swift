//
//  AppConfig.swift
//  Unwrap
//
//  Created by OpenAI on 30/05/2026.
//  Copyright © 2026 Hacking with Swift.
//

struct AppConfig: Codable {
    var pointsForLearning: Int
    var pointsForReviewing: Int
    var pointsForPracticing: Int
    var rankLevels: [Int]
    var smallestRankFraction: Double
}
