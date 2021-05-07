//
//  Search.swift
//  Jimo
//
//  Created by Gautam Mekkat on 11/13/20.
//

import SwiftUI
import MapKit
import ASCollectionView


let placeSearchEnabled = false // Not super useful right now

struct Search: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var globalViewState: GlobalViewState
    @Environment(\.backgroundColor) var backgroundColor
    
    @StateObject var searchViewModel = SearchViewModel()
    @StateObject var discoverViewModel = DiscoverViewModel()
    
    @State var initialLoadCompleted = false
    
    let defaultImage: Image = Image(systemName: "person.crop.circle")
    
    private var columns: [GridItem] = [
        GridItem(.flexible(minimum: 50), spacing: 10),
        GridItem(.flexible(minimum: 50), spacing: 10),
        GridItem(.flexible(minimum: 50), spacing: 10)
    ]
    
    func profilePicture(user: User) -> some View {
        URLImage(url: user.profilePictureUrl, loading: defaultImage, failure: defaultImage)
            .frame(width: 40, height: 40, alignment: .center)
            .font(Font.title.weight(.ultraLight))
            .foregroundColor(.gray)
            .background(Color.white)
            .cornerRadius(50)
            .padding(.trailing)
    }
    
    func profileView(user: User) -> some View {
        Profile(profileVM: ProfileVM(appState: appState, globalViewState: globalViewState, user: user))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarColor(UIColor(backgroundColor))
            .toolbar(content: {
                ToolbarItem(placement: .principal) {
                    NavTitle("Profile")
                }
            })
    }
    
    var discoverFeed: some View {
        if !discoverViewModel.initialized {
            return AnyView(ProgressView().padding(.top, 20))
        } else {
            return AnyView(discoverFeedLoaded)
        }
    }
    
    var discoverFeedLoaded: some View {
        ASCollectionView {
            ASCollectionViewSection(id: 1, data: discoverViewModel.posts) { post, _ in
                GeometryReader { geometry in
                    NavigationLink(destination: ViewPost(postId: post.postId)) {
                        URLImage(url: post.imageUrl, thumbnail: true)
                            .frame(maxWidth: .infinity)
                            .frame(height: geometry.size.width)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .background(Color(post.category))
                .cornerRadius(10)
            }
        }
        .alwaysBounceVertical()
        .shouldScrollToAvoidKeyboard(false)
        .layout {
            .grid(
                layoutMode: .fixedNumberOfColumns(3),
                itemSpacing: 10,
                lineSpacing: 10,
                itemSize: .estimated(80),
                sectionInsets: .init(top: 0, leading: 10, bottom: 0, trailing: 10)
            )
        }
        .scrollIndicatorsEnabled(horizontal: false, vertical: false)
        .onPullToRefresh { onFinish in
            discoverViewModel.loadDiscoverPage(onFinish: onFinish)
        }
        .ignoresSafeArea(.keyboard, edges: .all)
    }
    
    var userResults: some View {
        List(searchViewModel.userResults, id: \.username) { (user: PublicUser) in
            NavigationLink(destination: profileView(user: user)) {
                HStack {
                    profilePicture(user: user)
                    
                    VStack(alignment: .leading) {
                        Text(user.firstName + " " + user.lastName)
                            .font(Font.custom(Poppins.medium, size: 16))
                        Text("@" + user.username)
                            .font(Font.custom(Poppins.regular, size: 14))
                    }
                }
            }
        }
        .gesture(DragGesture().onChanged { _ in hideKeyboard() })
        .colorMultiply(backgroundColor)
        .listStyle(PlainListStyle())
    }
    
    var placeResults: some View {
        VStack {
            List(searchViewModel.placeResults) { (searchCompletion: MKLocalSearchCompletion) in
                HStack {
                    VStack(alignment: .leading) {
                        Text(searchCompletion.title)
                            .font(Font.custom(Poppins.medium, size: 16))
                        Text(searchCompletion.subtitle)
                            .font(Font.custom(Poppins.regular, size: 14))
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    hideKeyboard()
                    searchViewModel.selectPlace(appState: appState, completion: searchCompletion)
                }
            }
            .colorMultiply(backgroundColor)
            .listStyle(PlainListStyle())
            
            if let place = searchViewModel.selectedPlaceResult {
                NavigationLink(destination: ViewPlace(viewPlaceVM: ViewMKMapItemVM(mapItem: place))
                                .background(backgroundColor)
                                .navigationBarTitleDisplayMode(.inline)
                                .navigationBarColor(UIColor(backgroundColor))
                                .toolbar {
                                    ToolbarItem(placement: .principal) {
                                        NavTitle("View place")
                                    }
                                },
                               isActive: $searchViewModel.showPlaceResult) {
                    EmptyView()
                }
            }
        }
    }
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                SearchBar(
                    text: $searchViewModel.query,
                    isActive: $searchViewModel.searchBarFocused,
                    placeholder: "Search users"
                )
                .padding(.bottom, 0)
                
                if placeSearchEnabled {
                    Picker(selection: $searchViewModel.searchType, label: Text("What do you want to search for")) {
                        Text("People").tag(SearchType.people)
                        Text("Places").tag(SearchType.places)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                if !searchViewModel.searchBarFocused {
                    discoverFeed
                } else if searchViewModel.searchType == .people {
                    userResults
                } else if searchViewModel.searchType == .places {
                    placeResults
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(backgroundColor)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarColor(UIColor(backgroundColor))
            .toolbar {
                ToolbarItem(placement: .principal) {
                    NavTitle("Discover")
                }
            }
            .appear {
                if !initialLoadCompleted {
                    discoverViewModel.appState = appState
                    searchViewModel.listen(appState: appState)
                    discoverViewModel.loadDiscoverPage(initialLoad: true)
                    initialLoadCompleted = true
                }
                discoverViewModel.listenToPostUpdates()
            }
            .disappear {
                discoverViewModel.stopListeningToPostUpdates()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct Search_Previews: PreviewProvider {
    
    static var previews: some View {
        Search()
    }
}
