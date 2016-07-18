//
//  UILabel.swift
//  Camera
//
//  Created by Vitaliy Delidov on 7/18/16.
//  Copyright © 2016 Vitaliy Delidov. All rights reserved.
//

import Foundation
import UIKit

extension UILabel {
    func blink() {
        alpha = 0.0
        UIView.animateWithDuration(0.5,
                                   delay: 0.0,
                                   options: [.CurveEaseInOut, .Autoreverse, .Repeat],
                                   animations: { [weak self] in self?.alpha = 1.0 },
                                   completion: { [weak self] _ in self?.alpha = 0.0 })
    }
}