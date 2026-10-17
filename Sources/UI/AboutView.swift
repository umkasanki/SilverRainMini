import SwiftUI

/// The «О программе» pane of the Settings window.
struct AboutView: View {
    private static let station = URL(string: "https://silver.ru")!
    private static let sourceCode = URL(string: "https://github.com/umkasanki/SilverRainMini")!

    var body: some View {
        VStack(spacing: 14) {
            Image("StationLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text("Silver Rain Mini")
                    .font(.title2.weight(.semibold))
                Text("Версия \(Self.version)")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                Text("Радио «Серебряный Дождь» в строке меню: включил и слушаешь.")
                Text("Создано слушателями по примеру приложения «Серебряный Дождь» для Windows.")
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            HStack(spacing: 20) {
                Link("silver.ru", destination: Self.station)
                Link("Исходный код на GitHub", destination: Self.sourceCode)
            }

            Text("Неофициальное приложение. Название и логотип принадлежат радиостанции «Серебряный Дождь».")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 28)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }

    private static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String
        return build.map { "\(short) (\($0))" } ?? short
    }
}
