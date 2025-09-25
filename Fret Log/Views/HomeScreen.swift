//
//  HomeScreen.swift
//  Fret Log
//
//  Created by ian schoenrock on 9/22/25.
//

import SwiftUI

struct HomeScreen: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel = HomeViewModel()
    @State private var currentTime = Date()
    @State var showNewLogScreen = false
    @State var showLogDetailsScreen = false
    @State var selectedLog: GuitarLog? = nil
    
    var body: some View {
        NavigationStack{
            VStack{
                HStack{Spacer()}
                ScrollView{
                    ForEach(viewModel.guitarLogs, id: \.self){ log in
                        LogListItem(log: log).padding(.horizontal).padding(.vertical, 8).onTapGesture {
                            selectedLog = log
                            showLogDetailsScreen = true
                        }
                    }
                }
                Spacer()
                Button("Add New Log"){
                    showNewLogScreen = true
                }
            }
            .navigationDestination(isPresented: $showNewLogScreen){
                NewLogScreen()
            }
            .navigationDestination(isPresented: $showLogDetailsScreen){
                if(selectedLog != nil){
                    LogDetailsScreen(log: selectedLog!)
                }
            }
            .onAppear{
                viewModel.setContext(viewContext)
                viewModel.fetchLogs()
            }
        }
        
    }
}

#Preview {
    HomeScreen()
}



