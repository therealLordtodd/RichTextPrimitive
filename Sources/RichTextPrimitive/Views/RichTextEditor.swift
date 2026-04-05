import SwiftUI

public struct RichTextEditor: View {
    @Bindable private var state: RichTextState
    private let dataSource: any RichTextDataSource
    private let styleSheet: TextStyleSheet

    public init(
        state: RichTextState,
        dataSource: any RichTextDataSource,
        styleSheet: TextStyleSheet = .standard
    ) {
        self.state = state
        self.dataSource = dataSource
        self.styleSheet = styleSheet
    }

    public var body: some View {
        PlatformRichTextViewRepresentable(
            state: state,
            dataSource: dataSource,
            styleSheet: styleSheet
        )
    }
}
