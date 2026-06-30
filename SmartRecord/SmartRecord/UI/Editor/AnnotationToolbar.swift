import SwiftUI

struct AnnotationToolbar: View {
    let addText: () -> Void
    let addArrow: () -> Void
    let addHighlight: () -> Void
    let addBlur: () -> Void
    let addImage: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            tool("textformat", "文字", action: addText)
            tool("arrow.up.right", "箭头", action: addArrow)
            tool("rectangle", "高亮", action: addHighlight)
            tool("eye.slash", "模糊", action: addBlur)
            tool("photo", "图片/LOGO", action: addImage)
        }
    }

    private func tool(_ icon: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.bordered)
        .help(help)
    }
}
