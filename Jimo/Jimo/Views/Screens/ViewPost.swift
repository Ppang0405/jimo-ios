//
//  ViewPost.swift
//  Jimo
//
//  Created by Gautam Mekkat on 1/5/21.
//

import SwiftUI
import ASCollectionView

class PostDeletionListener: ObservableObject {
    let nc = NotificationCenter.default
    
    var postId: PostId?
    var onDelete: (() -> ())?
    
    func onPostDelete(postId: PostId, onDelete: @escaping () -> ()) {
        if self.postId != nil {
            // already observing
            return
        }
        self.postId = postId
        self.onDelete = onDelete
        nc.addObserver(self, selector: #selector(postDeleted), name: PostPublisher.postDeleted, object: nil)
    }
    
    @objc func postDeleted(notification: Notification) {
        guard let postId = postId, let onDelete = onDelete else {
            return
        }
        let deletedPostId = notification.object as! PostId
        if postId == deletedPostId {
            onDelete()
        }
    }
}

struct ViewPost: View {
    let postDeletionListener = PostDeletionListener()
    
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var globalViewState: GlobalViewState
    @Environment(\.presentationMode) var presentationMode
    
    @StateObject private var commentsViewModel = CommentsViewModel()
    @State private var initializedComments = false
    @State private var imageSize = CGSize.zero
    
    let post: Post
    var highlightedComment: Comment? = nil
    
    var colorTheme: Color {
        return Color(post.category)
    }
    
    var isMyPost: Bool {
        if case let .user(user) = appState.currentUser {
            return user.username == post.user.username
        }
        // Should never be here since user should be logged in
        return false
    }
    
    var postItem: some View {
        TrackedImageFeedItemV2(post: post, fullPost: true, imageSize: $imageSize)
            .fixedSize(horizontal: false, vertical: true)
            .onAppear {
                postDeletionListener.onPostDelete(postId: post.id, onDelete: { presentationMode.wrappedValue.dismiss() })
            }
    }
    
    var commentField: some View {
        CommentInputField(text: $commentsViewModel.newCommentText, buttonColor: colorTheme, onSubmit: { [weak commentsViewModel] in
            commentsViewModel?.createComment()
        })
    }
    
    var body: some View {
        ASCollectionView {
            ASCollectionViewSection(id: imageSize == .zero ? 0 : -1) {
                postItem
            }
            
            ASCollectionViewSection(id: 1) {
                ZStack {
                    commentField
                    
                    if commentsViewModel.creatingComment {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.gray.opacity(0.2))
                    }
                }
            }
            
            ASCollectionViewSection(id: 2, data: commentsViewModel.comments) { comment, _ in
                ZStack(alignment: .bottom) {
                    CommentItem(commentsViewModel: commentsViewModel, comment: comment, isMyPost: isMyPost)
                    Divider()
                        .foregroundColor(.gray)
                        .padding(.horizontal, 10)
                }
                .background(Color("background"))
                .fixedSize(horizontal: false, vertical: true)
            }
            .sectionFooter {
                VStack {
                    if commentsViewModel.loadingComments {
                        ProgressView()
                    }
                    Spacer().frame(height: 150)
                }
                .padding(.top, 20)
            }
        }
        .backgroundColor(UIColor(Color("background")))
        .shouldScrollToAvoidKeyboard(true)
        .layout(interSectionSpacing: 0) { sectionId in
            switch sectionId {
            case 0: // post
                return .list(itemSize: .estimated(300), spacing: 0)
            default:
                return .list(itemSize: .estimated(50), spacing: 0)
            }
        }
        .alwaysBounceVertical()
        .onReachedBoundary { boundary in
            if boundary == .bottom {
                commentsViewModel.loadMore()
            }
        }
        .scrollIndicatorsEnabled(horizontal: false, vertical: false)
        .onPullToRefresh { onFinish in
            commentsViewModel.loadComments(onFinish: onFinish)
        }
        .onAppear {
            if !initializedComments {
                initializedComments = true
                commentsViewModel.highlightedComment = highlightedComment
                commentsViewModel.postId = post.postId
                commentsViewModel.appState = appState
                commentsViewModel.viewState = globalViewState
                commentsViewModel.loadComments()
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarColor(UIColor(Color("background")))
        .toolbar(content: {
            ToolbarItem(placement: .principal) {
                NavTitle("View Post")
            }
        })
    }
}
