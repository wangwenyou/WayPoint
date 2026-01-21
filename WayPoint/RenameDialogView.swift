import SwiftUI

struct RenameDialogView: View {
    @ObservedObject var vm: WayPointViewModel
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // 背景遮罩
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture { vm.cancelRename() }
            
            // 弹窗本体
            VStack(spacing: 16) {
                Text(NSLocalizedString("Set Alias", comment: ""))
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let item = vm.renamingItem {
                    Text(item.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                TextField("Enter alias...", text: $vm.renameInput)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(10)
                    .background(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                    )
                    .font(.system(size: 14))
                    .focused($isFocused)
                    .onSubmit { vm.submitRename() }
                
                HStack(spacing: 12) {
                    Button(action: { vm.cancelRename() }) {
                        Text(NSLocalizedString("Cancel", comment: ""))
                            .font(.system(size: 13))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.escape, modifiers: [])
                    
                    Button(action: { vm.submitRename() }) {
                        Text(NSLocalizedString("Save", comment: ""))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .frame(width: 320)
            .background(VisualEffectView(material: .popover, blendingMode: .withinWindow))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.2), radius: 20, y: 10)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
    }
}
