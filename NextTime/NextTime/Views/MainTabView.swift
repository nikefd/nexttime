//
//  MainTabView.swift
//  NextTime
//
//  主标签页视图
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label(String(localized: "tab.home"), systemImage: "house.fill")
                }
                .tag(0)

            HistoryView()
                .tabItem {
                    Label(String(localized: "tab.history"), systemImage: "clock.fill")
                }
                .tag(1)

            LearnView()
                .tabItem {
                    Label(String(localized: "tab.learn"), systemImage: "book.fill")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label(String(localized: "tab.settings"), systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(.blue)
    }
}

#Preview {
    MainTabView()
}
