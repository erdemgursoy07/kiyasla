#!/usr/bin/env bash
# Kıyasla — iPhone uygulamasını tek komutla derle ve telefona yükle
#
#   bash kur.sh            iPhone projesini hazırlar, derler ve kabloyla bağlı iPhone'a yükler
#   bash kur.sh magaza     App Store için arşiv oluşturur ve Xcode'da gönderme ekranını açar
#   bash kur.sh kontrol    Yayındaki sürümü ve dosyaları kontrol eder
#   bash kur.sh eposta     Gizlilik politikasına e-posta adresini yazar
#
# Gerekenler: Mac, Xcode (bir kez açılıp lisansı kabul edilmiş), Xcode > Settings > Accounts'ta Apple hesabın.

set -u
ADRES="https://kiyasla.erdemgursoy07.workers.dev"
ALAN="kiyasla.erdemgursoy07.workers.dev"
BUNDLE_ID="com.erdemgursoy.kiyasla"
KLASOR="$(cd "$(dirname "$0")" && pwd)"
IOS="$KLASOR/ios"
cd "$KLASOR" || exit 1

yesil() { printf "\033[32m%s\033[0m\n" "$1"; }
sari()  { printf "\033[33m%s\033[0m\n" "$1"; }
kirmizi() { printf "\033[31m%s\033[0m\n" "$1"; }
baslik() { printf "\n\033[1m== %s ==\033[0m\n" "$1"; }
dur() { kirmizi "$1"; exit 1; }
var_mi() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
araclar() {
  baslik "Araçlar kontrol ediliyor"
  [ "$(uname)" = "Darwin" ] || dur "Bu betik sadece Mac'te çalışır."
  xcodebuild -version >/dev/null 2>&1 || dur "Xcode bulunamadı. App Store'dan Xcode'u kur, bir kez açıp lisansı kabul et."
  yesil "Xcode: $(xcodebuild -version | head -1)"

  # XcodeGen: Xcode projesini dosyalardan üretir (kurulum gerektirmez, klasöre indirilir)
  XCODEGEN=""
  if var_mi xcodegen; then XCODEGEN="xcodegen"
  elif [ -x "$IOS/.arac/xcodegen/bin/xcodegen" ]; then XCODEGEN="$IOS/.arac/xcodegen/bin/xcodegen"
  else
    sari "Proje oluşturucu (XcodeGen) indiriliyor..."
    mkdir -p "$IOS/.arac"
    if curl -fsSL "https://github.com/yonaskolb/XcodeGen/releases/latest/download/xcodegen.zip" -o "$IOS/.arac/xcodegen.zip" \
       && unzip -qo "$IOS/.arac/xcodegen.zip" -d "$IOS/.arac"; then
      XCODEGEN="$IOS/.arac/xcodegen/bin/xcodegen"
    fi
    if [ ! -x "$XCODEGEN" ] && ! var_mi "$XCODEGEN"; then
      if var_mi brew; then brew install xcodegen && XCODEGEN="xcodegen"; else dur "XcodeGen indirilemedi. İnternet bağlantını kontrol edip tekrar dene."; fi
    fi
  fi
  yesil "XcodeGen hazır."
}

# ---------------------------------------------------------------------------
takim_bul() {
  # Apple geliştirici takım kimliğini (Team ID) bir kez bulup kaydeder
  if [ -f "$IOS/.team" ]; then TEAM=$(cat "$IOS/.team"); return; fi
  TEAM=$(security find-certificate -a -c "Apple Development" -p 2>/dev/null \
    | openssl x509 -noout -subject 2>/dev/null \
    | sed -n 's/.*OU *= *\([A-Z0-9]\{10\}\).*/\1/p' | head -1)
  if [ -z "$TEAM" ]; then
    sari "Apple geliştirici takım kimliğin (Team ID) otomatik bulunamadı."
    echo "Bulmak için: developer.apple.com/account > Membership details > Team ID (10 karakter)."
    echo "Hesabın Xcode'a ekli değilse önce Xcode > Settings > Accounts'tan Apple hesabını ekle."
    printf "Team ID: "; read -r TEAM
  fi
  echo "$TEAM" | grep -qE '^[A-Z0-9]{10}$' || dur "Team ID 10 karakterli olmalı (ör. AB12CD34EF)."
  mkdir -p "$IOS" && echo "$TEAM" > "$IOS/.team"
  yesil "Team ID: $TEAM"
}

# ---------------------------------------------------------------------------
proje_olustur() {
  baslik "iPhone projesi hazırlanıyor"
  local K="$IOS/Kiyasla"
  mkdir -p "$K/Assets.xcassets/AppIcon.appiconset" "$K/Assets.xcassets/LaunchBG.colorset"

  cp "$KLASOR/magaza/app-store-simge-1024.png" "$K/Assets.xcassets/AppIcon.appiconset/icon-1024.png" || dur "magaza/app-store-simge-1024.png bulunamadı."
  cat > "$K/Assets.xcassets/Contents.json" <<'J'
{ "info" : { "author" : "xcode", "version" : 1 } }
J
  cat > "$K/Assets.xcassets/AppIcon.appiconset/Contents.json" <<'J'
{ "images" : [ { "filename" : "icon-1024.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" } ],
  "info" : { "author" : "xcode", "version" : 1 } }
J
  cat > "$K/Assets.xcassets/LaunchBG.colorset/Contents.json" <<'J'
{ "colors" : [
    { "idiom" : "universal", "color" : { "color-space" : "srgb", "components" : { "red" : "0.941", "green" : "0.953", "blue" : "0.925", "alpha" : "1.000" } } },
    { "idiom" : "universal", "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ],
      "color" : { "color-space" : "srgb", "components" : { "red" : "0.063", "green" : "0.090", "blue" : "0.071", "alpha" : "1.000" } } } ],
  "info" : { "author" : "xcode", "version" : 1 } }
J

  cat > "$K/App.swift" <<'SWIFT'
import UIKit
import WebKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let c = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        c.delegateClass = SceneDelegate.self
        return c
    }
}

// Yeni iOS sürümleri açılışın "sahne" (scene) yapısıyla yapılmasını zorunlu tutuyor
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let w = UIWindow(windowScene: windowScene)
        w.rootViewController = WebViewController()
        w.makeKeyAndVisible()
        window = w
    }
}

final class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    private let adres = URL(string: "https://kiyasla.erdemgursoy07.workers.dev/")!
    private let alan = "kiyasla.erdemgursoy07.workers.dev"
    private var webView: WKWebView!

    override func loadView() {
        let ayar = WKWebViewConfiguration()
        ayar.limitsNavigationsToAppBoundDomains = true   // internetsiz çalışma (service worker) için gerekli
        ayar.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: ayar)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsLinkPreview = false
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never   // güvenli alanları sayfa kendisi ayarlıyor
        webView.isOpaque = false
        webView.backgroundColor = UIColor(named: "LaunchBG")
        webView.scrollView.backgroundColor = UIColor(named: "LaunchBG")
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        webView.load(URLRequest(url: adres))
    }

    // Kıyasla dışındaki bağlantılar (marka siteleri, kaynaklar) Safari'de açılır
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if url.host == alan || url.scheme == "about" || url.scheme == "data" || navigationAction.targetFrame?.isMainFrame == false {
            decisionHandler(.allow)
        } else {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url { UIApplication.shared.open(url) }
        return nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let html = """
        <html><head><meta name='viewport' content='width=device-width,initial-scale=1'>
        <style>body{font-family:-apple-system;display:flex;flex-direction:column;align-items:center;justify-content:center;height:90vh;margin:24px;text-align:center;color:#142218;background:#F0F3EC}
        @media(prefers-color-scheme:dark){body{color:#EEF2EA;background:#101712}}
        button{font:600 17px -apple-system;border:0;border-radius:14px;padding:14px 28px;background:#2F6B3F;color:#fff;margin-top:16px}</style></head>
        <body><h2>İnternete bağlanılamadı</h2><p>Kıyasla’yı ilk açışta internet gerekiyor. Bağlantını kontrol edip tekrar dene.</p>
        <button onclick="location.href='https://kiyasla.erdemgursoy07.workers.dev/'">Tekrar dene</button></body></html>
        """
        webView.loadHTMLString(html, baseURL: adres)
    }
}
SWIFT

  cat > "$IOS/project.yml" <<YML
name: Kiyasla
options:
  deploymentTarget:
    iOS: "16.0"
targets:
  Kiyasla:
    type: application
    platform: iOS
    sources: [Kiyasla]
    settings:
      base:
        PRODUCT_NAME: Kiyasla
        PRODUCT_BUNDLE_IDENTIFIER: $BUNDLE_ID
        MARKETING_VERSION: "1.0"
        CURRENT_PROJECT_VERSION: "$(date +%Y%m%d%H%M)"
        TARGETED_DEVICE_FAMILY: "1"
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        CODE_SIGN_STYLE: Automatic
        DEVELOPMENT_TEAM: $TEAM
        SWIFT_VERSION: "5.0"
        GENERATE_INFOPLIST_FILE: NO
    info:
      path: Kiyasla/Info.plist
      properties:
        CFBundleDisplayName: Kıyasla
        CFBundleShortVersionString: \$(MARKETING_VERSION)
        CFBundleVersion: \$(CURRENT_PROJECT_VERSION)
        LSRequiresIPhoneOS: true
        UILaunchScreen:
          UIColorName: LaunchBG
        UIApplicationSceneManifest:
          UIApplicationSupportsMultipleScenes: false
          UISceneConfigurations:
            UIWindowSceneSessionRoleApplication:
              - UISceneConfigurationName: Default Configuration
                UISceneDelegateClassName: \$(PRODUCT_MODULE_NAME).SceneDelegate
        UISupportedInterfaceOrientations: [UIInterfaceOrientationPortrait]
        UIRequiresFullScreen: true
        WKAppBoundDomains: [$ALAN]
        ITSAppUsesNonExemptEncryption: false
YML

  (cd "$IOS" && "$XCODEGEN" generate --quiet) || dur "Xcode projesi oluşturulamadı."
  yesil "Proje hazır: ios/Kiyasla.xcodeproj"
}

# ---------------------------------------------------------------------------
cihaz_bul() {
  local json="$IOS/build/cihazlar.json"; mkdir -p "$IOS/build"
  xcrun devicectl list devices --json-output "$json" >/dev/null 2>&1
  CIHAZ=$(/usr/bin/python3 - "$json" <<'PY' 2>/dev/null
import json,sys
try: d=json.load(open(sys.argv[1]))
except Exception: sys.exit()
for c in d.get("result",{}).get("devices",[]):
    hw=c.get("hardwareProperties",{}); cp=c.get("connectionProperties",{})
    if hw.get("platform")=="iOS" and hw.get("deviceType","iPhone")=="iPhone" and cp.get("pairingState")=="paired":
        print(c.get("identifier","")+"|"+c.get("deviceProperties",{}).get("name","iPhone")); break
PY
)
}

derle_yukle() {
  araclar; takim_bul; proje_olustur
  baslik "Derleniyor (ilk seferde birkaç dakika sürebilir)"
  xcodebuild -project "$IOS/Kiyasla.xcodeproj" -scheme Kiyasla -configuration Debug \
    -destination "generic/platform=iOS" -derivedDataPath "$IOS/build" \
    -allowProvisioningUpdates -quiet build \
    || { kirmizi "Derleme başarısız oldu."
         echo "En sık sebep: Xcode > Settings > Accounts'ta Apple hesabın ekli değil. Ekleyip tekrar 'bash kur.sh' yaz."
         exit 1; }
  local APP="$IOS/build/Build/Products/Debug-iphoneos/Kiyasla.app"
  [ -d "$APP" ] || dur "Derlenen uygulama bulunamadı."
  yesil "Derleme tamam."

  baslik "iPhone'a yükleniyor"
  cihaz_bul
  if [ -z "${CIHAZ:-}" ]; then
    kirmizi "Bağlı bir iPhone bulunamadı."
    echo "1. iPhone'u kabloyla Mac'e bağla, kilidini aç, 'Bu bilgisayara güven' de."
    echo "2. iPhone'da Ayarlar > Gizlilik ve Güvenlik > Geliştirici Modu'nu aç (telefon yeniden başlar)."
    echo "3. Sonra tekrar 'bash kur.sh' yaz."
    exit 1
  fi
  local ID="${CIHAZ%%|*}" AD="${CIHAZ#*|}"
  echo "Cihaz: $AD"
  xcrun devicectl device install app --device "$ID" "$APP" >/dev/null || dur "Yükleme başarısız. iPhone'un kilidinin açık olduğundan emin olup tekrar dene."
  xcrun devicectl device process launch --device "$ID" "$BUNDLE_ID" >/dev/null 2>&1 \
    || sari "Uygulama yüklendi ama otomatik açılamadı. Ücretsiz Apple hesabı kullanıyorsan iPhone'da Ayarlar > Genel > VPN ve Cihaz Yönetimi'nden geliştiriciye güven, sonra simgeye dokun."
  yesil "Kıyasla iPhone'una yüklendi."
}

magaza() {
  araclar; takim_bul; proje_olustur
  baslik "App Store arşivi oluşturuluyor"
  rm -rf "$IOS/build/Kiyasla.xcarchive"
  xcodebuild -project "$IOS/Kiyasla.xcodeproj" -scheme Kiyasla -configuration Release \
    -destination "generic/platform=iOS" -archivePath "$IOS/build/Kiyasla.xcarchive" \
    -allowProvisioningUpdates -quiet archive || dur "Arşiv oluşturulamadı."
  yesil "Arşiv hazır. Xcode'da açılan pencerede 'Distribute App' > 'App Store Connect' de."
  open "$IOS/build/Kiyasla.xcarchive"
}

kontrol() {
  baslik "Yayındaki sürüm kontrolü"
  local yerel uzak kod
  yerel=$(grep -o "SURUM = 'v[0-9]*'" public/sw.js | grep -o "v[0-9]*")
  uzak=$(curl -fsS "$ADRES/sw.js" 2>/dev/null | grep -o "SURUM = 'v[0-9]*'" | grep -o "v[0-9]*")
  echo "Bu klasör: ${yerel:-?}   Yayında: ${uzak:-ulaşılamadı}"
  if [ -n "$uzak" ] && [ "$uzak" = "$yerel" ]; then yesil "Yayındaki sürüm güncel."; else sari "Yayındaki sürüm farklı; public ve src klasörlerini GitHub'a yükle."; fi
  for yol in "/" "/manifest.webmanifest" "/gizlilik.html"; do
    kod=$(curl -s -o /dev/null -w "%{http_code}" "$ADRES$yol")
    if [ "$kod" = "200" ]; then yesil "  $yol açılıyor"; else kirmizi "  $yol açılmıyor (HTTP $kod)"; fi
  done
  if grep -q "\[E-POSTA ADRESİN\]" public/gizlilik.html; then sari "  Gizlilik politikasında e-posta yok: bash kur.sh eposta"; fi
}

eposta() {
  grep -q "\[E-POSTA ADRESİN\]" public/gizlilik.html || { yesil "E-posta zaten yazılmış."; return; }
  printf "E-posta adresin: "; read -r e
  case "$e" in *@*.*) ;; *) dur "Geçerli bir e-posta gibi görünmüyor.";; esac
  E="$e" perl -0pi -e 's/\[E-POSTA ADRESİN\]/$ENV{E}/g' public/gizlilik.html && yesil "Yazıldı. public klasörünü GitHub'a tekrar yükle."
}

xcode_ac() { araclar; takim_bul; proje_olustur; open "$IOS/Kiyasla.xcodeproj"; yesil "Xcode açıldı. Üstten iPhone'unu seç ve ▶ (Run) düğmesine bas."; }

case "${1:-}" in
  xcode)   xcode_ac ;;
  magaza)  magaza ;;
  kontrol) kontrol ;;
  eposta)  eposta ;;
  *)       derle_yukle ;;
esac
