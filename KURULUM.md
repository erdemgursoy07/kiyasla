# Kıyasla – Kurulum Rehberi

Bu rehber, hiç yazılım deneyimi olmadan uygulamanı önce internette yayınlamanı, sonra App Store’a göndermeni anlatır. Adımları sırayla takip et. Ekranlardaki buton adları zamanla değişebilir; bulamazsan benzer adlı butonu ara.

## Klasörde ne var?

- `public/index.html` – Uygulamanın kendisi.
- `public/gizlilik.html` – Gizlilik politikası. App Store bunu zorunlu tutar. İçindeki `[E-POSTA ADRESİN]` yerini kendi e-postanla değiştir (`bash kur.sh` → 4).
- `public/manifest.webmanifest`, `public/sw.js`, `public/icons/` – Uygulamanın telefona yüklenebilmesini, simgesini ve internetsiz açılmasını sağlar.
- `src/index.js` ve `wrangler.jsonc` – Sunucu kısmı ve Cloudflare ayarları. Gemini anahtarın Cloudflare’de gizli kalır, dosyalarda yer almaz.

## Toplam maliyet

| Ne | Ücret |
|---|---|
| Gemini API (ücretsiz kota) | 0 TL |
| Cloudflare Workers (barındırma) | 0 TL |
| GitHub | 0 TL |
| Apple geliştirici hesabı | 99 dolar, her yıl |

---

## 1. Adım: Gemini API anahtarını al (5 dakika)

1. https://aistudio.google.com adresine Google hesabınla gir.
2. **Get API key** (API anahtarı al) butonuna, sonra **Create API key** butonuna bas.
3. Çıkan uzun metni kopyala ve güvenli bir yere kaydet. Bu anahtarı kimseyle paylaşma.

Önemli: Faturalandırmayı (billing) açma. Açmazsan ücretsiz kotayı aştığında sadece geçici olarak çalışmaz, sana ücret çıkmaz.

## 2. Adım: Dosyaları GitHub’a yükle (10 dakika)

1. https://github.com adresinde ücretsiz hesap aç.
2. Sağ üstteki **+** işaretine, sonra **New repository**’ye bas. Ad olarak `kiyasla` yaz, **Private** seç ve **Create repository** de.
3. Açılan sayfada **uploading an existing file** bağlantısına tıkla.
4. Bu zip dosyasını bilgisayarında aç. İçindeki `public` ve `src` klasörlerini, `wrangler.jsonc` ve `KURULUM.md` dosyalarını Finder’dan (ya da Dosya Gezgini’nden) **klasör olarak** sürükleyip sayfaya bırak. “choose your files” penceresini kullanma; o pencere klasörleri düzleştirir.
5. Alttaki **Commit changes** butonuna bas.

## 3. Adım: Uygulamayı Cloudflare’de yayınla (10 dakika)

1. https://dash.cloudflare.com adresinde ücretsiz hesap aç.
2. Soldaki menüden **Workers & Pages**’e gir, **Create**’e bas ve **Import a repository** (GitHub’dan içe aktar) seçeneğini seç.
3. GitHub hesabını bağla ve `kiyasla` deposunu seç.
4. Ayarlar ekranında **Deploy command** olarak `npx wrangler deploy` yazılı olmalı; kök klasör `/` kalsın. Diğer ayarlara dokunma (`wrangler.jsonc` dosyası gerisini halleder).
5. **Deploy**’a bas. İlk yayın bitince projeye gir, **Settings → Variables and Secrets** bölümünde **Add** de ve şunu ekle:
   - **Type:** Secret
   - **Variable name:** `GEMINI_API_KEY`
   - **Value:** 1. adımda aldığın anahtar
6. Kaydettikten sonra adresin şuna benzer olacak: `https://kiyasla.erdemgursoy07.workers.dev`

Bu adresi telefonunda aç ve yapay zekâ kutusunu dene. Çalışıyorsa uygulaman artık internette!

Telefonda hemen kullanmak için: iPhone’da Safari’de paylaş butonundan **Ana Ekrana Ekle**.

Sorun çıkarsa: Yapay zekâ “henüz ayarlanmamış” diyorsa anahtar eklenmemiştir. Cloudflare’de projeye gir, **Settings → Variables and Secrets** bölümünden ekle ve **Deployments** sekmesinden yeniden yayınla (Retry deployment).

---

## 4. Adım: App Store’a gönder

Bu adım dosyanın sonundaki **“iPhone uygulaması (App Store)”** bölümünde adım adım anlatılıyor.

---

## Uygulamayı nasıl güncellerim?

GitHub’da `public/index.html` dosyasını değiştirip kaydettiğinde Cloudflare siteyi otomatik günceller. Mağazadaki uygulamalar da bu siteyi gösterdiği için çoğu güncellemede mağazaya yeniden göndermen gerekmez. Değişiklik yaptığında `public/sw.js` dosyasındaki `SURUM = 'v1'` değerini `v2`, `v3` diye artır ki telefonlardaki eski kopya yenilensin.

## Güvenlik notları

- Gemini anahtarını asla `index.html` içine yazma; sadece Cloudflare ayarlarında dursun.
- Uygulaman herkese açık olduğu için başkaları da yapay zekâ özelliğini kullanabilir. Faturalandırma kapalı olduğu sürece bu sana ücret çıkarmaz, en kötü ihtimalle günlük ücretsiz kota dolar.
- Gemini model adı zamanla değişebilir. Yapay zekâ bir gün çalışmayı bırakırsa Cloudflare’de `GEMINI_MODEL` adında bir değişken ekleyip Google AI Studio’da gördüğün güncel model adını yazabilirsin.

---

## Güvenlik: bot koruması (Turnstile) — isteğe bağlı

Sunucu zaten sadece Kıyasla’nın kendi adresinden gelen istekleri kabul ediyor ve aynı kişiden dakikada 8, günde 120’den fazla yapay zekâ isteğini reddediyor. Bunlar kurulum gerektirmez. Ek olarak görünmez bot korumasını açmak istersen:

1. Cloudflare panelinde soldaki menüden **Turnstile**’a gir ve **Add widget** de.
2. Ad olarak `Kıyasla` yaz. **Hostname** kısmına `kiyasla.erdemgursoy07.workers.dev` ekle.
3. **Widget Mode** olarak **Invisible** (görünmez) seç ve oluştur.
4. Sana iki anahtar verilecek: **Site Key** ve **Secret Key**.
5. `kiyasla` Worker’ının **Settings → Variables and Secrets** bölümüne iki değişken ekle:
   - `TURNSTILE_SITE` → türü **Text**, değeri Site Key
   - `TURNSTILE_SECRET` → türü **Secret**, değeri Secret Key
6. Kaydettikten sonra koruma kendiliğinden açılır; uygulamada bir şey değiştirmen gerekmez. Kapatmak için bu iki değişkenden birini silmen yeterli.

## Google aramasıyla doğrulama

Uygulama yayındaki sürümde yapay zekâ ile cihaz eklerken ve bir cihazın detayındaki **“Bilgileri internetten kontrol et”** butonunda Gemini’nin Google aramasını kullanır; kullanılan kaynaklar cihazın altında listelenir. Bu özelliğin ücretsiz kotası Google AI Studio’daki hesabına bağlıdır. Kota dolarsa uygulama “çok fazla istek” uyarısı verir; ertesi gün yeniden çalışır.


---

## iPhone uygulaması (App Store)

**Kısa yol:** iPhone’u kabloyla Mac’e bağla, Terminal’de bu klasöre gir ve `bash kur.sh` yaz. Betik iPhone projesini kendisi oluşturur, derler ve telefona yükler. App Store’a göndermek için `bash kur.sh magaza`, yayını kontrol için `bash kur.sh kontrol`, gizlilik e-postası için `bash kur.sh eposta`.

İlk seferde bir kez gerekenler: Xcode > Settings > Accounts’ta Apple hesabın ekli olmalı; iPhone’da “Bu bilgisayara güven” denmiş ve Ayarlar > Gizlilik ve Güvenlik > Geliştirici Modu açık olmalı. Aşağıdaki PWABuilder adımları, betik yerine elle yapmak istersen alternatif yoldur.

Kıyasla bir web uygulaması. iPhone paketini **PWABuilder** hazırlıyor: uygulama içeriği her zaman workers.dev adresinden geldiği için, GitHub’a yaptığın güncellemeler App Store’a yeni sürüm göndermeden de telefonlara yansır. Simge veya uygulama adı gibi paketin kendisini değiştirmek istersen yeni sürüm göndermen gerekir.

### Gerekenler
- Bir **Mac** ve App Store’dan ücretsiz **Xcode**
- **Apple Developer Program** üyeliği (yıllık ücretli; developer.apple.com)
- **CocoaPods** (kur.sh yoksa kurmayı teklif eder)

### Adımlar
1. **Yayını kontrol et:** `bash kur.sh` → 1. Her satır yeşil olmalı.
2. **Gizlilik e-postası:** `bash kur.sh` → 4, sonra `public` klasörünü GitHub’a tekrar yükle. Gizlilik adresin: `https://kiyasla.erdemgursoy07.workers.dev/gizlilik.html`
3. **Projeyi hazırla:** `bash kur.sh` → 3. Tarayıcıda PWABuilder açılır; **Package For Stores → iOS → Generate Package** de. Bundle ID için kalıcı bir ad yaz (ör. `com.erdemgursoy.kiyasla`). İnen zip’i Terminal’e sürükle; betik paketi açar, gerekli kütüphaneleri kurar ve projeyi Xcode’da açar.
4. **Xcode’da:**
   - Sol üstte projeye tıkla → **Signing & Capabilities** → **Team** olarak Apple Developer hesabını seç.
   - **General → Supported Destinations** bölümünde sadece **iPhone** bırakmanı öneririm; iPad açık kalırsa App Store senden iPad ekran görüntüleri de ister.
   - Önce kendi iPhone’unu kabloyla bağlayıp **Run (▶)** ile dene.
   - Sorun yoksa üstten **Any iOS Device** seç → **Product → Archive** → **Distribute App → App Store Connect**.
5. **App Store Connect’te (appstoreconnect.apple.com):** Yeni uygulama oluştur (aynı Bundle ID), önce **TestFlight** ile kendin dene, sonra incelemeye gönder.

### App Store sayfası için hazırlaman gerekenler
- **Uygulama adı (30 karakter):** Kıyasla: Cihaz Karşılaştır
- **Alt başlık (30 karakter):** Telefon, tablet, laptop kıyasla
- **Simge:** `magaza/app-store-simge-1024.png` hazır.
- **Ekran görüntüleri:** En büyük iPhone ekran boyutu için en az 3 dikey ekran görüntüsü: ana sayfa (iki cihaz seçili, farklar görünürken), seçim paneli, karşılaştırma ekranı (çubuklar dolu) ve cihaz detayı. En kolayı Xcode’daki iPhone simülatöründe en büyük modeli seçip uygulamayı açmak ve Cmd+S ile kaydetmek.
- **Gizlilik bilgileri (App Privacy):** Uygulama kişisel veri toplamıyor. Yapay zekâ özelliklerinde sadece cihaz adları Google’a gidiyor ve kimseyle ilişkilendirilmiyor. Formu doldururken takıldığın soruyu bana sor.
- **Yaş sınırı:** 4+

### İnceleme hakkında
Apple, sadece bir web sitesini saran uygulamaları (Kılavuz 4.2, “asgari işlevsellik”) reddedebilir. Kıyasla’nın internetsiz açılması, kendi karşılaştırma ekranı, Benim cihazım ve uygulama turu bu riski azaltır ama tamamen ortadan kaldırmaz. Reddedilirsen gelen mesajı bana gönder; birlikte cevap yazar ya da gerekeni ekleriz.
