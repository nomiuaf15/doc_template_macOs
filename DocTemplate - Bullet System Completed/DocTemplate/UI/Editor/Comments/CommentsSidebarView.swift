import SwiftUI

struct CommentsSidebarView: View {
    @Binding var comments: [DocComment]
    @Binding var versions: [VersionSnapshot]
    
    var onRestoreVersion: (VersionSnapshot) -> Void
    var onResolveComment: (String) -> Void
    var onAddReply: (String, String) -> Void
    
    var body: some View {
        
        VStack(alignment: .leading, spacing: 0) {
            
            versionsSection
            
        }
        .frame(minWidth: 200, maxWidth: 280)
        
    }
    
    // MARK: - Versions
    private var versionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            HStack {
                
                Text("Versions")
                    .font(.system(size: 13, weight: .semibold))
                
                Spacer()
                
                Text("\(versions.count)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            if versions.isEmpty {
                Text("No saved versions yet.")
                    .font(
                        .system(size: 11)
                    )
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
            } else {
                
                ScrollView(showsIndicators: false) {
                    
                    LazyVStack(alignment: .leading, spacing: 5) {
                        
                        ForEach(versions) { version in
                            
                            Button {
                                onRestoreVersion(version)
                            } label: {
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    
                                    Text(version.name)
                                        .font(.system(size: 12, weight: .medium))
                                    
                                    Text(version.date, style: .date)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                    
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(.blue.opacity(0.15))
                                )
                                .contentShape(Rectangle())
                                
                            }
                            .buttonStyle(.plain)
                            
                        }
                        
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 10)
                    
                }
                .frame(maxHeight: .infinity)
            }
            
        }
        .frame(maxHeight: .infinity)
        
    }
    
    // MARK: - Comments
    private var commentsSection: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            HStack {
                Text("Comments")
                    .font(
                        .system(
                            size: 13,
                            weight: .semibold
                        )
                    )
                
                Spacer()
                
                Text("\(comments.count)")
                    .font(
                        .system(size: 11)
                    )
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            if comments.isEmpty {
                VStack(spacing: 8) {
                    Image(
                        systemName:
                            "bubble.left"
                    )
                    .font(
                        .system(size: 22)
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    
                    Text(
                        "Comments you add to the document will appear here."
                    )
                    .font(
                        .system(size: 11)
                    )
                    .foregroundStyle(
                        .secondary
                    )
                    .multilineTextAlignment(
                        .center
                    )
                }
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
                .padding()
            } else {
                ScrollView {
                    LazyVStack(
                        alignment: .leading,
                        spacing: 8
                    ) {
                        ForEach(
                            comments
                        ) { comment in
                            commentCard(
                                comment
                            )
                        }
                    }
                    .padding(10)
                }
            }
        }
    }
    
    // MARK: - Comment Card
    private func commentCard(_ comment: DocComment) -> some View {
        
        VStack(alignment: .leading, spacing: 6) {
            
            HStack(spacing: 6) {
            
                Image(systemName: comment.avatarName)
                
                Text(comment.author)
                    .font(.system(size: 11, weight: .semibold))
                
                Spacer()
                
                if comment.isResolved {
                    
                    Text("Resolved")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                    
                }
                
            }
            
            if !comment.quotedText.isEmpty {
                
                Text(comment.quotedText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Color.secondary
                            .opacity(0.08)
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: 5)
                    )
            }
            
            Text(comment.text)
                .font(.system(size: 12))
                .foregroundStyle(
                    comment.isResolved
                    ? .secondary
                    : .primary
                )
            
            ForEach(comment.replies) { reply in
                
                HStack(alignment: .top, spacing: 6) {
                    
                    Image(systemName: "arrowshape.turn.up.left")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        
                        Text(reply.author)
                            .font(.system(size: 10, weight: .semibold))
                        
                        Text(reply.text)
                            .font(.system(size: 11))
                        
                    }
                    
                }
                .padding(.leading, 8)
            }
            
            Divider()
            
            HStack(spacing: 12) {
                
                Button {
                    onResolveComment(comment.id.uuidString)
                } label: {
                    
                    Label(comment.isResolved ? "Reopen" : "Resolve", systemImage: comment.isResolved ? "arrow.uturn.backward" : "checkmark.circle")
                    
                }
                .buttonStyle(.borderless)
                
                Button {
                    
                    onAddReply(comment.id.uuidString, "Reply text")
                    
                } label: {
                    
                    Image(systemName: "arrowshape.turn.up.left")
                    
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
            }
            .font(.system(size: 10))
            
        }
        .padding(9)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(
            RoundedRectangle(cornerRadius: 7)
        )
        
    }
    
}

struct CommentsSidebarView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        CommentsSidebarView(
            comments: .constant([]),
            versions: .constant([]),
            onRestoreVersion: { _ in },
            onResolveComment: { _ in },
            onAddReply: { _, _ in }
        )
        .frame(width: 280, height: 600)
        
    }
    
}
