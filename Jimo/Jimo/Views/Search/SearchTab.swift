//
//  SearchTab.swift
//  Jimo
//
//  Created by Gautam Mekkat on 2/12/23.
//

import SwiftUI

struct SearchTab: View {
    var body: some View {
        Navigator {
            SearchUsers()
                .trackScreen(.searchTab)
                .ignoresSafeArea(.keyboard, edges: .all)
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarColor(UIColor(Color("background")))
        }
    }
}
