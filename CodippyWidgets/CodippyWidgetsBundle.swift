//
//  CodippyWidgetsBundle.swift
//  CodippyWidgets
//

import SwiftUI
import WidgetKit

@main
struct CodippyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CurrentPostalCodeWidget()
        FavoritesWidget()
    }
}
