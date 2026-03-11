import Foundation

struct ChangelogFeature {
    let icon: String
    let title: String
    let description: String
}

struct ChangelogEntry: Identifiable {
    var id: String { version }
    let version: String
    let date: String
    let features: [ChangelogFeature]
}

enum Changelog {
    /// Adicione uma nova entrada aqui a cada atualização do app.
    /// O What's New sheet irá mostrar a entrada correspondente à versão atual.
    static let all: [ChangelogEntry] = [
        ChangelogEntry(
            version: "1.6",
            date: "Mar 2026",
            features: [
                ChangelogFeature(
                    icon: "play.rectangle.on.rectangle",
                    title: "Download Social Media",
                    description: "Baixe vídeos ou só o áudio do YouTube, Instagram, TikTok e +1000 plataformas direto do app."
                ),
                ChangelogFeature(
                    icon: "video.fill",
                    title: "Vídeo ou Só Áudio",
                    description: "Escolha entre MP4 em várias qualidades (1080p, 720p…) ou extração de MP3 com um clique."
                )
            ]
        ),
        ChangelogEntry(
            version: "1.5",
            date: "Mar 2026",
            features: [
                ChangelogFeature(
                    icon: "folder.badge.plus",
                    title: "Criar Pasta no Drive",
                    description: "Ao enviar arquivos, crie uma nova subpasta diretamente no Google Drive sem sair do app."
                ),
                ChangelogFeature(
                    icon: "plus.rectangle.on.folder",
                    title: "Criar Pasta no Finder",
                    description: "Ao baixar, crie uma nova pasta local no Finder e use-a como destino do download em segundos."
                )
            ]
        ),
        ChangelogEntry(
            version: "1.4",
            date: "Mar 2026",
            features: [
                ChangelogFeature(
                    icon: "folder.badge.plus",
                    title: "Preservar Estrutura de Pastas",
                    description: "Ao baixar uma pasta do Drive, o app agora cria automaticamente a subpasta com o nome original no destino — mantendo sua organização intacta."
                ),
                ChangelogFeature(
                    icon: "star.fill",
                    title: "Novidades em destaque",
                    description: "A partir de agora, você verá este resumo sempre que o app for atualizado com novas funções."
                )
            ]
        ),
        ChangelogEntry(
            version: "1.3",
            date: "Fev 2026",
            features: [
                ChangelogFeature(
                    icon: "clock.badge.checkmark",
                    title: "Retenção de Histórico",
                    description: "Configure por quanto tempo o histórico de downloads é mantido — 7, 30, 90 dias ou sem limite."
                ),
                ChangelogFeature(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Auto-Retry em Falhas",
                    description: "Downloads com falha são automaticamente tentados de novo com backoff exponencial."
                ),
                ChangelogFeature(
                    icon: "externaldrive.fill",
                    title: "Múltiplas Contas Drive",
                    description: "Adicione e alterne entre várias contas do Google Drive diretamente nas configurações."
                )
            ]
        )
    ]

    /// Retorna a entrada do changelog para a versão fornecida, se existir.
    static func entry(for version: String) -> ChangelogEntry? {
        all.first { $0.version == version }
    }
}
