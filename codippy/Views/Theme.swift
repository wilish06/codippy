//
//  Theme.swift
//  codippy
//
//  Sistema de diseño: gradiente de marca, fondo de malla y tarjetas.
//

import SwiftUI

enum Theme {
    static let accent = Color.indigo
}

/// Fondo de toda la app: liso, con un velo neutro para que resalten las tarjetas.
struct AppBackground: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.background)
            Rectangle().fill(Color.gray.opacity(0.07))
        }
        .ignoresSafeArea()
    }
}

private struct Card: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: .rect(cornerRadius: 22))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(.quaternary.opacity(0.5), lineWidth: 0.5)
            )
    }
}

extension View {
    func card() -> some View { modifier(Card()) }
}

/// El código postal como distintivo con el gradiente de marca.
struct CodeChip: View {
    let code: String
    var large = false

    var body: some View {
        Text(code)
            .font(.system(large ? .title2 : .subheadline, design: .rounded, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, large ? 14 : 10)
            .padding(.vertical, large ? 8 : 5)
            .background(Theme.accent, in: .rect(cornerRadius: large ? 14 : 9))
    }
}

/// Distintivo con el código ISO del país ("ES", "FR"…), en lugar de banderas.
struct CountryBadge: View {
    let code: String

    var body: some View {
        Text(code.uppercased())
            .font(.caption.weight(.bold))
            .monospaced()
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Theme.accent.opacity(0.12), in: .rect(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Theme.accent.opacity(0.25), lineWidth: 0.5)
            )
    }
}

/// Fila de detalle con icono de color, etiqueta y valor.
struct InfoRow: View {
    let icon: String
    let tint: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(tint, in: .rect(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.body.weight(.medium))
            }
            Spacer(minLength: 0)
        }
    }
}
