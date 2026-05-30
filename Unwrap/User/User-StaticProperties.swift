//
//  User-StaticProperties.swift
//  Unwrap
//
//  Created by Paul Hudson on 09/08/2018.
//  Copyright © 2019 Hacking with Swift.
//

import UIKit

extension User {
    static var current: User!

    /// How many points we award for fixed tasks.
    static var pointsForLearning: Int { Unwrap.config.pointsForLearning }
    static var pointsForReviewing: Int { Unwrap.config.pointsForReviewing }
    static var pointsForPracticing: Int { Unwrap.config.pointsForPracticing } // per question answered correctly

    /// Stores the highest score for a given rank bracket.
    static var rankLevels: [Int] { Unwrap.config.rankLevels }

    /// Allows us to draw a little of the activity ring even when the user has no rank fraction.
    static var smallestRankFraction: Double { Unwrap.config.smallestRankFraction }
}
