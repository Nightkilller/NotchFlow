import SwiftUI

// MARK: - NotchFlow Brand Logo

/// Vector rendering of the official NotchFlow logo: 4 rows of orange teleprompter speech capsules.
struct NotchFlowLogo: View {
    var size: CGFloat = 20
    var color: Color = AppColors.accent
    
    var body: some View {
        VStack(alignment: .leading, spacing: size * 0.10) {
            let pillH = size * 0.15
            
            // Row 1: Long (58%), Gap (8%), Short (34%)
            HStack(spacing: size * 0.08) {
                Capsule()
                    .fill(color)
                    .frame(width: size * 0.66, height: pillH)
                Capsule()
                    .fill(color)
                    .frame(width: size * 0.36, height: pillH)
            }
            
            // Row 2: Short (20%), Gap (7%), Medium (33%), Gap (7%), Medium (33%)
            HStack(spacing: size * 0.07) {
                Capsule()
                    .fill(color)
                    .frame(width: size * 0.22, height: pillH)
                Capsule()
                    .fill(color)
                    .frame(width: size * 0.38, height: pillH)
                Capsule()
                    .fill(color)
                    .frame(width: size * 0.38, height: pillH)
            }
            
            // Row 3: Medium (30%), Gap (8%), Long (62%)
            HStack(spacing: size * 0.08) {
                Capsule()
                    .fill(color)
                    .frame(width: size * 0.34, height: pillH)
                Capsule()
                    .fill(color)
                    .frame(width: size * 0.68, height: pillH)
            }
            
            // Row 4: Medium (62%)
            Capsule()
                .fill(color)
                .frame(width: size * 0.68, height: pillH)
        }
        .frame(width: size * 1.15, height: size)
    }
}

