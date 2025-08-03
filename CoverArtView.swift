import SwiftUI

struct CoverArtView: View {
    let image: Image
    let uiImage: UIImage?
    let maxWidth: CGFloat
    let maxHeight: CGFloat

    var aspectRatio: CGFloat? {
        guard let uiImage = uiImage else { return nil }
        return uiImage.size.width / uiImage.size.height
    }

    var body: some View {
        if let aspect = aspectRatio {
            // Display in correct aspect ratio
            image
                .resizable()
                .aspectRatio(aspect, contentMode: .fit)
                .frame(
                    width: min(maxWidth, maxHeight * aspect),
                    height: min(maxHeight, maxWidth / aspect)
                )
        } else {
            // Fall back to square
            image
                .resizable()
                .aspectRatio(1, contentMode: .fit)
                .frame(width: maxWidth, height: maxWidth)
        }
    }
}
