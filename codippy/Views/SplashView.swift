//
//  SplashView.swift
//  codippy
//
//  Pantalla de bienvenida (solo iOS). Arranca exactamente igual que la pantalla
//  de lanzamiento del sistema (mismo color y mismo icono centrado) y desde ahí
//  anima: el icono rebota, una onda se expande desde el pin y aparece el nombre.
//  Con "Reducir movimiento" se limita a un fundido breve.
//

#if os(iOS)
import SwiftUI

struct SplashView: View {
    /// Se llama cuando la animación ha terminado y la vista ya puede retirarse.
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var iconScale: CGFloat = 1
    @State private var ripple: CGFloat = 0
    @State private var rippleOpacity: Double = 0
    @State private var secondRipple: CGFloat = 0
    @State private var secondRippleOpacity: Double = 0
    @State private var showTitle = false
    @State private var showTagline = false
    @State private var glow: CGFloat = 0.6

    private static let brand = Color("LaunchBackground")

    var body: some View {
        ZStack {
            Self.brand.ignoresSafeArea()

            // Halo suave detrás del icono.
            RadialGradient(
                colors: [.white.opacity(0.22), .white.opacity(0)],
                center: .center, startRadius: 10, endRadius: 210
            )
            .frame(width: 420, height: 420)
            .scaleEffect(glow)
            .allowsHitTesting(false)

            // Ondas que salen desde el pin del icono.
            Circle()
                .strokeBorder(.white.opacity(0.9), lineWidth: 3)
                .frame(width: 132, height: 132)
                .scaleEffect(ripple)
                .opacity(rippleOpacity)
            Circle()
                .strokeBorder(.white.opacity(0.6), lineWidth: 2)
                .frame(width: 132, height: 132)
                .scaleEffect(secondRipple)
                .opacity(secondRippleOpacity)

            VStack(spacing: 22) {
                Image("LaunchIcon")
                    .resizable()
                    .frame(width: 132, height: 132)
                    .overlay(
                        RoundedRectangle(cornerRadius: 29.5, style: .continuous)
                            .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                    )
                    .scaleEffect(iconScale)
                    .shadow(color: .black.opacity(0.35), radius: 22, y: 12)

                VStack(spacing: 6) {
                    Text("Codippy")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .opacity(showTitle ? 1 : 0)
                        .offset(y: showTitle ? 0 : 10)
                    Text("Encuentra cualquier código postal")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.75))
                        .opacity(showTagline ? 1 : 0)
                        .offset(y: showTagline ? 0 : 6)
                }
                // El bloque de texto no desplaza el icono: sigue donde lo dejó la pantalla de lanzamiento.
                .frame(height: 0, alignment: .top)
            }
        }
        .task { await play() }
        .accessibilityHidden(true)
    }

    private func play() async {
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.3)) { showTitle = true; showTagline = true }
            try? await Task.sleep(for: .milliseconds(900))
            onFinished()
            return
        }

        // Pequeña pausa para que el sistema termine su transición de lanzamiento.
        try? await Task.sleep(for: .milliseconds(120))

        withAnimation(.spring(response: 0.42, dampingFraction: 0.55)) { iconScale = 1.12 }
        withAnimation(.easeOut(duration: 1.1)) { glow = 1.35 }
        withAnimation(.easeOut(duration: 0.9)) { ripple = 3.2; rippleOpacity = 0 }
        rippleOpacity = 0.9
        withAnimation(.easeOut(duration: 0.9)) { rippleOpacity = 0 }

        try? await Task.sleep(for: .milliseconds(160))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { iconScale = 1 }
        secondRippleOpacity = 0.6
        withAnimation(.easeOut(duration: 0.9)) { secondRipple = 2.6; secondRippleOpacity = 0 }

        try? await Task.sleep(for: .milliseconds(140))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { showTitle = true }
        try? await Task.sleep(for: .milliseconds(120))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { showTagline = true }

        try? await Task.sleep(for: .milliseconds(950))
        onFinished()
    }
}

#Preview {
    SplashView {}
}
#endif
