//
//  ImageCollection.swift
//  imageviewer
//
//  Created by Codex on 4/5/26.
//

import Foundation

protocol ImageCollection {
    var items: [ImageItem] { get }
    var sourceDescription: String { get }
}
