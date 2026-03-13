#!/bin/bash
# fazer-instalador.sh
# Cria um DMG completo do Iris Downloader para distribuição
# Funciona em Apple Silicon (M1/M2/M3) E Intel - sem precisar de conta Apple
set -e

VERSION="1.7"
APP_NAME="Iris Downloader"
DMG_NAME="IrisDownloader-${VERSION}-instalador.dmg"
VOLUME_NAME="Iris Downloader ${VERSION}"
APP_BUNDLE="${APP_NAME}.app"

echo "========================================================"
echo "  Iris Downloader - Criando Instalador Universal v${VERSION}"
echo "========================================================"
echo ""

# ── 1. Build Universal Binary (Apple Silicon + Intel) ─────────────────────────
echo "[1/4] Compilando para Apple Silicon (arm64)..."
swift build -c release --arch arm64

echo "[1/4] Compilando para Intel (x86_64)..."
swift build -c release --arch x86_64

echo "[1/4] Criando binário universal..."
lipo -create \
  .build/arm64-apple-macosx/release/IrisDownloader \
  .build/x86_64-apple-macosx/release/IrisDownloader \
  -output .build/release-universal-IrisDownloader

echo "   ✅ Binário universal criado."
echo ""

# ── 2. Montar o bundle .app ───────────────────────────────────────────────────
echo "[2/4] Montando o bundle .app..."

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources/Fonts"

# Usa o binário universal
cp .build/release-universal-IrisDownloader "$APP_BUNDLE/Contents/MacOS/IrisDownloader"
chmod +x "$APP_BUNDLE/Contents/MacOS/IrisDownloader"

# Ícone
cp AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

# Fontes
cp Resources/Fonts/NeueMontreal-Regular.otf "$APP_BUNDLE/Contents/Resources/Fonts/"
cp Resources/Fonts/NeueMontreal-Medium.otf  "$APP_BUNDLE/Contents/Resources/Fonts/"
cp Resources/Fonts/NeueMontreal-Bold.otf    "$APP_BUNDLE/Contents/Resources/Fonts/"
cp Resources/Fonts/NeueMontreal-Light.otf   "$APP_BUNDLE/Contents/Resources/Fonts/"

# Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>pt-BR</string>
    <key>CFBundleExecutable</key>
    <string>IrisDownloader</string>
    <key>CFBundleIdentifier</key>
    <string>com.irismedia.IrisDownloader</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>5</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>ATSApplicationFontsPath</key>
    <string>Fonts</string>
</dict>
</plist>
PLIST

# Assina ad-hoc (necessário para rodar; o script instalador vai remover quarentena)
codesign --force --deep --sign - "$APP_BUNDLE"
echo "   ✅ Bundle criado e assinado."
echo ""

# ── 3. Staging dir ────────────────────────────────────────────────────────────
echo "[3/4] Preparando conteúdo do DMG..."
STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT

# Copia o .app
cp -r "$APP_BUNDLE" "$STAGING/"

# Atalho para /Applications (arrastar clássico)
ln -s /Applications "$STAGING/Applications"

# ── README para o usuário ──────────────────────────────────────────────────────
cat > "$STAGING/📖 LEIA-ME - Como Instalar.txt" << 'README_EOF'
╔════════════════════════════════════════════════════╗
║          Iris Downloader - Como Instalar           ║
╚════════════════════════════════════════════════════╝

  Você tem 2 opções para instalar:

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  OPÇÃO A — Instalação rápida (recomendado)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  PASSO 1:
    Clique com o botão DIREITO no arquivo:
    👉 "Instalar Iris Downloader.command"
    Depois clique em "Abrir"
    ⚠️  Use BOTÃO DIREITO → Abrir (não duplo clique)

  PASSO 2:
    Se aparecer aviso "desenvolvedor não verificado":
    → Clique em "Abrir" ou "Abrir assim mesmo"

  PASSO 3:
    O Terminal vai abrir. Siga as instruções.
    Quando pedir sua senha do Mac → é normal, confirme.

  O que o instalador faz automaticamente:
    ✓ Instala o Iris Downloader em /Applications
    ✓ Libera o app no Gatekeeper (segurança do Mac)
    ✓ Instala o Homebrew (se não tiver)
    ✓ Instala o rclone (necessário para downloads)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  OPÇÃO B — Arrastar manualmente
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  PASSO 1:
    Arraste o ícone "Iris Downloader" para a pasta
    "Applications" que aparece na mesma janela.
    (Como instalar qualquer app Mac normal)

  PASSO 2:
    Se aparecer aviso ao abrir o app:
    → Vá em: Preferências do Sistema > Privacidade e
      Segurança > clique "Abrir assim mesmo"

  ⚠️  ATENÇÃO: A Opção B não instala o rclone.
      Você precisará instalar manualmente com:
      brew install rclone

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  PROBLEMAS?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Se o Mac bloquear o app, abra o Terminal e cole:
  sudo xattr -cr "/Applications/Iris Downloader.app"

  Requisito mínimo: macOS 13 (Ventura) ou superior.

README_EOF

# ── Script instalador ──────────────────────────────────────────────────────────
cat > "$STAGING/Instalar Iris Downloader.command" << 'INSTALLER_EOF'
#!/bin/bash
# Instalador do Iris Downloader
# Clique direito → Abrir para executar

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_SOURCE="$SCRIPT_DIR/Iris Downloader.app"
APP_DEST="/Applications/Iris Downloader.app"

clear
echo "╔═══════════════════════════════════════════════╗"
echo "║        Instalação do Iris Downloader          ║"
echo "╚═══════════════════════════════════════════════╝"
echo ""

# ── Verificar macOS ───────────────────────────────────────────────────────────
OS_MAJOR=$(sw_vers -productVersion | cut -d. -f1)
OS_MINOR=$(sw_vers -productVersion | cut -d. -f2)
echo "🖥️  macOS detectado: $(sw_vers -productVersion)"

if [ "$OS_MAJOR" -lt 13 ]; then
    echo ""
    echo "❌ ERRO: Iris Downloader requer macOS 13 (Ventura) ou superior."
    echo "   Seu Mac tem macOS $(sw_vers -productVersion)."
    echo ""
    read -p "Pressione Enter para fechar..."
    exit 1
fi

# ── Detectar arquitetura ──────────────────────────────────────────────────────
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    echo "💻 Arquitetura: Apple Silicon (M1/M2/M3) ✅"
else
    echo "💻 Arquitetura: Intel ✅"
fi
echo ""

# ── Passo 1: Instalar o app ───────────────────────────────────────────────────
echo "📱 [1/3] Instalando Iris Downloader..."

# Remove versão anterior se existir
if [ -d "$APP_DEST" ]; then
    echo "   Removendo versão anterior..."
    sudo rm -rf "$APP_DEST"
fi

if sudo cp -r "$APP_SOURCE" /Applications/; then
    echo "   ✅ App instalado em /Applications."
else
    echo "   ⚠️  Instalando na pasta do usuário..."
    mkdir -p ~/Applications
    cp -r "$APP_SOURCE" ~/Applications/
    APP_DEST="$HOME/Applications/Iris Downloader.app"
    echo "   ✅ App instalado em ~/Applications."
fi

# Remove quarentena do Gatekeeper
echo "   🔓 Liberando no Gatekeeper..."
sudo xattr -cr "$APP_DEST" 2>/dev/null || xattr -cr "$APP_DEST" 2>/dev/null || true
echo "   ✅ App liberado."
echo ""

# ── Passo 2: Homebrew ─────────────────────────────────────────────────────────
echo "🍺 [2/3] Verificando Homebrew..."

if ! command -v brew &> /dev/null; then
    echo "   Homebrew não encontrado. Instalando..."
    echo "   (pode demorar alguns minutos na primeira vez)"
    echo ""
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    echo ""
fi

# Garante brew no PATH para Apple Silicon e Intel
if [[ -f "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -f "/usr/local/bin/brew" ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

echo "   ✅ Homebrew OK."
echo ""

# ── Passo 3: rclone ───────────────────────────────────────────────────────────
echo "📦 [3/3] Verificando rclone..."

if command -v rclone &> /dev/null; then
    echo "   ✅ rclone já instalado: $(rclone --version | head -1)"
else
    echo "   Instalando rclone via Homebrew..."
    brew install rclone
    echo "   ✅ rclone instalado: $(rclone --version | head -1)"
fi
echo ""

# ── Concluído ─────────────────────────────────────────────────────────────────
echo "════════════════════════════════════════════════"
echo "  ✅  Instalação concluída! Abrindo o app..."
echo "════════════════════════════════════════════════"
echo ""
echo "  Se o app não abrir automaticamente, procure"
echo "  por 'Iris Downloader' no Launchpad."
echo ""

sleep 1
open "$APP_DEST" 2>/dev/null || open -a "Iris Downloader" 2>/dev/null || true

read -p "Pressione Enter para fechar este terminal..."
INSTALLER_EOF

chmod +x "$STAGING/Instalar Iris Downloader.command"

# ── 4. Cria o DMG ─────────────────────────────────────────────────────────────
echo "[4/4] Criando DMG..."

rm -f "$DMG_NAME"

hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    -fs HFS+ \
    "$DMG_NAME"

# ── Resultado ─────────────────────────────────────────────────────────────────
echo ""
echo "========================================================"
echo "✅  Instalador criado com sucesso!"
echo ""
echo "   📦 Arquivo: $DMG_NAME"
SIZE=$(du -sh "$DMG_NAME" | cut -f1)
echo "   📏 Tamanho: $SIZE"
echo ""
echo "   Envie o arquivo '$DMG_NAME' para seu colega."
echo ""
echo "   Instruções para o colega:"
echo "   1. Abra o DMG"
echo "   2. Clique DIREITO em 'Instalar Iris Downloader.command'"
echo "   3. Clique em 'Abrir'"
echo "   4. Siga as instruções na tela"
echo "========================================================"
echo ""
