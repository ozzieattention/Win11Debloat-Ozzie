<#
  Win11 Debloat Ozzie — Seçmeli (GUI) Windows 11 debloat + oyun performansı + uygulama kurulumu
  Yapan: Ozzie
  Özellik listesi Raphire/Win11Debloat (MIT) projesinden esinlenildi, kod sıfırdan yazıldı.

  Çalıştırma: Run.bat'a çift tıkla (veya)
    powershell -ExecutionPolicy Bypass -File .\Win11Debloat_Ozzie.ps1

  Kullanım (adım adım sihirbaz):
    Başlangıç -> Uygulama kaldırma -> Ayarlar -> Kurulacak uygulamalar -> Özet -> UYGULA
    "Kodu kontrol et" scriptteki her komutun/parametrenin bu Windows'ta var olduğunu doğrular.

  Listede bile olmayanlar: Store, Windows Update'i kapatma, TPM/Secure Boot/VBS/HVCI,
  Xbox Identity Provider/TCUI -> FACEIT AC ve Vanguard etkilenmez.
#>

# ---------- Yönetici değilse kendini yönetici olarak yeniden aç ----------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ---------- Yardımcılar ----------
function Set-Reg {
    param([string]$Path, [string]$Name, $Value, [string]$Type = 'DWord')
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}
function Update-UI {
    # Bekleyen çizim/olayları işle ki arayüz donmasın
    $window.Dispatcher.Invoke([Action]{}, [Windows.Threading.DispatcherPriority]::Background)
}
$script:LogTarget = $null
function Log([string]$msg) {
    if ($script:LogTarget) { $script:LogTarget.AppendText("$msg`r`n"); $script:LogTarget.ScrollToEnd() }
    Update-UI
}
function Wait-UI([int]$ms) {
    $end = (Get-Date).AddMilliseconds($ms)
    while ((Get-Date) -lt $end) { Update-UI; Start-Sleep -Milliseconds 50 }
}

$adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'

$hasNvidia = [bool](Get-CimInstance Win32_VideoController | Where-Object { $_.Name -like '*NVIDIA*' })
$isLaptop  = [bool](Get-CimInstance Win32_Battery)

# ---------- Ayar tanımları ----------
function Twk($Cat, $Name, $Desc, $Def, [scriptblock]$Run) {
    [pscustomobject]@{ Cat = $Cat; Name = $Name; Desc = $Desc; Def = [bool]$Def; Run = $Run; CB = $null }
}

$Tweaks = @(
# --- Gizlilik ---
Twk 'Gizlilik' 'Telemetri ve tanılama verilerini kapat' 'DiagTrack/dmwappushservice servisleri + telemetri policy + geri bildirim istekleri.' $true {
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'DoNotShowFeedbackNotifications' 1
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'AllowTelemetry' 0
    Set-Reg 'HKCU:\Software\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' 0
    foreach ($s in 'DiagTrack', 'dmwappushservice') { Stop-Service -Name $s -Force; Set-Service -Name $s -StartupType Disabled }
}
Twk 'Gizlilik' 'Telemetri zamanlanmış görevlerini kapat' 'Compatibility Appraiser, CEIP Consolidator/UsbCeip, Feedback DmClient.' $true {
    $list = @(
        @('\Microsoft\Windows\Application Experience\', 'Microsoft Compatibility Appraiser'),
        @('\Microsoft\Windows\Application Experience\', 'ProgramDataUpdater'),
        @('\Microsoft\Windows\Customer Experience Improvement Program\', 'Consolidator'),
        @('\Microsoft\Windows\Customer Experience Improvement Program\', 'UsbCeip'),
        @('\Microsoft\Windows\Feedback\Siuf\', 'DmClient'),
        @('\Microsoft\Windows\Feedback\Siuf\', 'DmClientOnScenarioDownload')
    )
    foreach ($t in $list) { Disable-ScheduledTask -TaskPath $t[0] -TaskName $t[1] | Out-Null }
}
Twk 'Gizlilik' 'Reklam kimliği ve kişiselleştirilmiş reklamlar' 'Uygulamalar arası reklam takibi kapanır.' $true {
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' 'DisabledByGroupPolicy' 1
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 0
    Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\CloudContent' 'DisableTailoredExperiencesWithDiagnosticData' 1
}
Twk 'Gizlilik' 'Etkinlik geçmişi ve uygulama açılış takibi' 'Zaman çizelgesi verisi + Start "en çok kullanılanlar" takibi kapanır.' $true {
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableActivityFeed' 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'PublishUserActivities' 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'UploadUserActivities' 0
    Set-Reg $adv 'Start_TrackProgs' 0
}
Twk 'Gizlilik' 'Yazma/mürekkep verisi toplamayı kapat' 'Klavye ve kalem kişiselleştirme verisi gönderilmez.' $true {
    Set-Reg 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitInkCollection' 1
    Set-Reg 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitTextCollection' 1
}
Twk 'Gizlilik' 'Konum servisleri ve Cihazımı Bul' 'Hava durumu/harita gibi konum isteyen şeyler çalışmaz.' $false {
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' 'DisableLocation' 1
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' 'Value' 'Deny' 'String'
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\FindMyDevice' 'AllowFindMyDevice' 0
}

# --- Öneriler & Reklamlar ---
Twk 'Öneriler' 'İpuçları, öneriler ve sessiz uygulama kurulumu' 'Candy Crush tarzı otomatik kurulan uygulamalar + Ayarlar/Start önerileri.' $true {
    foreach ($n in 'SilentInstalledAppsEnabled', 'SystemPaneSuggestionsEnabled', 'SoftLandingEnabled',
                   'OemPreInstalledAppsEnabled', 'PreInstalledAppsEnabled', 'PreInstalledAppsEverEnabled',
                   'SubscribedContent-310093Enabled', 'SubscribedContent-338388Enabled', 'SubscribedContent-338389Enabled',
                   'SubscribedContent-338393Enabled', 'SubscribedContent-353694Enabled', 'SubscribedContent-353696Enabled') {
        Set-Reg $cdm $n 0
    }
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' 'ScoobeSystemSettingEnabled' 0
}
Twk 'Öneriler' 'Kilit ekranı ipuçları ve reklamları' 'Kilit ekranındaki "eğlenceli bilgiler" kapanır.' $true {
    Set-Reg $cdm 'RotatingLockScreenOverlayEnabled' 0
    Set-Reg $cdm 'SubscribedContent-338387Enabled' 0
}
Twk 'Öneriler' 'Explorer''da OneDrive/365 reklamları' 'Dosya Gezgini içindeki senkronizasyon bildirimleri.' $true {
    Set-Reg $adv 'ShowSyncProviderNotifications' 0
}
Twk 'Öneriler' 'Ayarlar "Giriş" sayfasını gizle' 'Microsoft 365/Game Pass reklamlı Ayarlar Ana sayfası kaybolur.' $false {
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'SettingsPageVisibility' 'hide:home' 'String'
}

# --- AI ---
Twk 'AI' 'Copilot''u kapat' 'Windows Copilot policy + görev çubuğu butonu.' $true {
    Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
    Set-Reg $adv 'ShowCopilotButton' 0
}
Twk 'AI' 'Recall ve Click to Do''yu kapat' 'Ekran görüntüsü kaydı ve AI eylemleri.' $true {
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 1
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'AllowRecallEnablement' 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableClickToDo' 1
    Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\WindowsAI' 'DisableClickToDo' 1
}
Twk 'AI' 'AI servisi (WSAIFabricSvc) otomatik başlamasın' 'Elle başlatmaya çekilir. Servis yoksa atlanır.' $true {
    if (Get-Service -Name WSAIFabricSvc) {
        Stop-Service -Name WSAIFabricSvc -Force
        Set-Service -Name WSAIFabricSvc -StartupType Manual
    } else { Log '   servis bu sistemde yok, atlandı' }
}
Twk 'AI' 'Paint ve Not Defteri AI özelliklerini kapat' 'Cocreator, Image Creator, generative fill, Not Defteri yeniden yazma.' $false {
    $p = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Paint'
    Set-Reg $p 'DisableCocreator' 1
    Set-Reg $p 'DisableGenerativeFill' 1
    Set-Reg $p 'DisableImageCreator' 1
    Set-Reg 'HKLM:\SOFTWARE\Policies\WindowsNotepad' 'DisableAIFeatures' 1
}

# --- Sistem ---
Twk 'Sistem' 'Klasik sağ tık menüsü (Win10 tarzı)' '"Daha fazla seçenek göster"e gerek kalmaz.' $true {
    # Anahtarın (Varsayılan) değeri boş string olmalı; New-Item -Value bunu doğrudan yazar
    New-Item -Path 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32' -Value '' -Force | Out-Null
}
Twk 'Sistem' 'Fare ivmesini kapat (İşaretçi hassasiyetini artır)' 'CS2/Valorant için ham aim. Oturumu kapatıp açınca tam oturur.' $true {
    Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseSpeed' '0' 'String'
    Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' '0' 'String'
    Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' '0' 'String'
}
Twk 'Sistem' 'Yapışkan Tuşlar kısayolunu kapat' '5x Shift popup''ı oyunda çıkmaz.' $true {
    Set-Reg 'HKCU:\Control Panel\Accessibility\StickyKeys' 'Flags' '506' 'String'
}
Twk 'Sistem' 'Hızlı başlatmayı kapat' 'Kapat-aç gerçek temiz açılış olur, BIOS''a girmek kolaylaşır.' $false {
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled' 0
}
Twk 'Sistem' 'Depolama Algısı otomatik temizliği kapat' 'Windows kendi kafasına göre dosya silmez.' $false {
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' '01' 0
}
Twk 'Sistem' 'BitLocker otomatik cihaz şifrelemesini engelle' 'Sadece bundan sonrasını engeller, şifreli diski çözmez.' $false {
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\BitLocker' 'PreventDeviceEncryption' 1
}

# --- Windows Update ---
Twk 'Güncelleme' 'Oturum açıkken otomatik yeniden başlatma yok' 'Maç ortasında restart yemezsin. Güncellemeler yine iner.' $true {
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' 'NoAutoRebootWithLoggedOnUsers' 1
}
Twk 'Güncelleme' 'Teslim İyileştirme (P2P güncelleme paylaşımı) kapat' 'İnternetin başka PC''lere güncelleme dağıtmak için kullanılmaz.' $true {
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' 0
}
Twk 'Güncelleme' '"En son güncellemeleri hemen al" kapat' 'Yeni özellikleri herkesle birlikte alırsın, erken değil.' $true {
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' 'IsContinuousInnovationOptedIn' 0
}
Twk 'Güncelleme' 'Cihaz yardımcı uygulamaları otomatik kurulmasın' 'Monitör/mouse takınca üretici uygulaması kendiliğinden inmez.' $false {
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Metadata' 'PreventDeviceMetadataFromNetwork' 1
}

# --- Görünüm ---
Twk 'Görünüm' 'Karanlık mod' 'Sistem + uygulamalar.' $false {
    $k = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    Set-Reg $k 'AppsUseLightTheme' 0
    Set-Reg $k 'SystemUsesLightTheme' 0
}
Twk 'Görünüm' 'Şeffaflığı kapat' '' $false {
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'EnableTransparency' 0
}
Twk 'Görünüm' 'Animasyonları kapat' 'Pencere küçültme/büyütme, görev çubuğu animasyonları, Aero Peek.' $false {
    Set-Reg 'HKCU:\Control Panel\Desktop\WindowMetrics' 'MinAnimate' '0' 'String'
    Set-Reg $adv 'TaskbarAnimations' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\DWM' 'EnableAeroPeek' 0
}
Twk 'Görünüm' 'Masaüstündeki "Bu resim hakkında bilgi edinin" simgesi' 'Spotlight arka planı kullanıyorsan çıkan simge gizlenir.' $false {
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel' '{2cc5ca98-6485-489a-920e-b3e88a6ccce3}' 1
}

# --- Start & Arama ---
Twk 'Start & Arama' 'Aramada Bing/web sonuçlarını kapat' 'Start araması sadece PC''yi arar.' $true {
    Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SearchSettings' 'IsDynamicSearchBoxEnabled' 0
}
Twk 'Start & Arama' 'Start "Önerilenler" reklamlarını ve hesap bildirimlerini gizle' '' $true {
    Set-Reg $adv 'Start_IrisRecommendations' 0
    Set-Reg $adv 'Start_AccountNotifications' 0
}
Twk 'Start & Arama' 'Start menüsündeki Telefon Bağlantısı panelini kapat' '' $false {
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Start\Companions\Microsoft.YourPhone_8wekyb3d8bbwe' 'IsEnabled' 0
}

# --- Görev Çubuğu ---
Twk 'Görev Çubuğu' 'Widgets''ı kapat' 'Görev çubuğu + kilit ekranı haber/hava durumu.' $true {
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0
}
Twk 'Görev Çubuğu' 'Sağ tıkta "Görevi sonlandır" seçeneği' 'Donan oyunu görev çubuğundan kapatırsın.' $true {
    Set-Reg "$adv\TaskbarDeveloperSettings" 'TaskbarEndTask' 1
}
Twk 'Görev Çubuğu' 'Chat/Teams ikonunu gizle' '' $true { Set-Reg $adv 'TaskbarMn' 0 }
Twk 'Görev Çubuğu' 'Simgeleri sola hizala' '' $false { Set-Reg $adv 'TaskbarAl' 0 }
Twk 'Görev Çubuğu' 'Arama kutusunu sadece simge yap' '' $false {
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode' 1
}
Twk 'Görev Çubuğu' 'Aramayı görev çubuğundan tamamen gizle' 'Üsttekiyle birlikte seçersen bu geçerli olur.' $false {
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode' 0
}
Twk 'Görev Çubuğu' 'Görev Görünümü butonunu gizle' '' $false { Set-Reg $adv 'ShowTaskViewButton' 0 }
Twk 'Görev Çubuğu' 'Son aktif pencereye tıkla (Last Active Click)' 'Gruplu simgeye tıklayınca son kullandığın pencere açılır.' $false { Set-Reg $adv 'LastActiveClick' 1 }
Twk 'Görev Çubuğu' 'Görev çubuğu düğmelerini asla birleştirme' 'Her pencere etiketiyle ayrı görünür.' $false { Set-Reg $adv 'TaskbarGlomLevel' 2 }

# --- Dosya Gezgini ---
Twk 'Dosya Gezgini' '"Bu Bilgisayar" ile aç' '' $true { Set-Reg $adv 'LaunchTo' 1 }
Twk 'Dosya Gezgini' 'Dosya uzantılarını göster' '' $true { Set-Reg $adv 'HideFileExt' 0 }
Twk 'Dosya Gezgini' 'Gizli dosya ve klasörleri göster' '' $false { Set-Reg $adv 'Hidden' 1 }
Twk 'Dosya Gezgini' 'Kenar çubuğunda "Giriş"i gizle' '' $false {
    Set-Reg 'HKCU:\Software\Classes\CLSID\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}' 'System.IsPinnedToNameSpaceTree' 0
}
Twk 'Dosya Gezgini' 'Kenar çubuğunda "Galeri"yi gizle' '' $false {
    Set-Reg 'HKCU:\Software\Classes\CLSID\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}' 'System.IsPinnedToNameSpaceTree' 0
}

# --- Çoklu Görev ---
Twk 'Çoklu Görev' 'Snap Layout/Snap Assist önerilerini kapat' 'Pencereyi kenara çekince çıkan öneri paneli.' $false {
    Set-Reg $adv 'EnableSnapAssistFlyout' 0
    Set-Reg $adv 'SnapAssist' 0
}
Twk 'Çoklu Görev' 'Alt+Tab''da Edge sekmelerini gösterme' 'Sadece pencereler görünür.' $true { Set-Reg $adv 'MultiTaskingAltTabFilter' 3 }

# --- Oyun Performansı ---
Twk 'Performans' 'Nihai Performans (Ultimate Performance) güç planı' $(if ($isLaptop) { 'LAPTOP algılandı: pil çok hızlı biter, şarjdayken mantıklı.' } else { 'CPU çekirdek park etme/frekans düşürme kapanır. Tekrar çalıştırınca kopya oluşturmaz.' }) (-not $isLaptop) {
    $planName = 'Ultimate Performance (Debloat Ozzie)'
    $guidRx   = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
    $list = (powercfg /list) | Out-String
    # Eski sürümün oluşturduğu "(Debloat TR)" planı da tanınır, kopya oluşmaz
    $m = [regex]::Match($list, "($guidRx)\s+\(Ultimate Performance \(Debloat (Ozzie|TR)\)\)")
    if ($m.Success) {
        $g = $m.Groups[1].Value
        powercfg /changename $g $planName | Out-Null
    } else {
        $out = (powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61) | Out-String
        $g = [regex]::Match($out, $guidRx).Value
        if ($g) { powercfg /changename $g $planName | Out-Null }
    }
    if ($g) { powercfg /setactive $g; Log "   aktif plan: $g" }
    else { Log '   ! plan oluşturulamadı' }
}
Twk 'Performans' 'USB seçici askıya almayı kapat' 'Mouse/klavye/kulaklık güç tasarrufu yüzünden uyumaz. Aktif güç planına uygulanır.' $true {
    powercfg /setacvalueindex scheme_current 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
    powercfg /setactive scheme_current
}
Twk 'Performans' 'Güç kısıtlamayı (Power Throttling) kapat' 'Arka plandaki uygulamalar (Discord, OBS) yavaşlatılmaz.' (-not $isLaptop) {
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff' 1
}
Twk 'Performans' 'Donanım hızlandırmalı GPU zamanlama (HAGS) aç' 'NVIDIA Frame Generation için gerekli, gecikmeyi düşürebilir. Yeniden başlatma ister.' $true {
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2
}
Twk 'Performans' 'Oyun Modu aç' 'Oyun açıkken Windows Update sürücü kurulumu/bildirimler ertelenir.' $true {
    Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
    Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1
}
Twk 'Performans' 'Pencereli oyunlar için iyileştirmeler aç' 'DX10/11 pencereli/borderless oyunlar flip model kullanır, gecikme düşer. Diğer grafik ayarların korunur.' $true {
    $k = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
    $cur = (Get-ItemProperty -Path $k -Name 'DirectXUserGlobalSettings').DirectXUserGlobalSettings
    $parts = @(([string]$cur) -split ';' | Where-Object { $_ -and $_ -notlike 'SwapEffectUpgradeEnable=*' })
    $new = (($parts + 'SwapEffectUpgradeEnable=1') -join ';') + ';'
    Set-Reg $k 'DirectXUserGlobalSettings' $new 'String'
}
Twk 'Performans' 'Multimedya zamanlayıcısını oyunlara öncelik verecek şekilde ayarla' 'SystemResponsiveness 10, ağ kısıtlaması kapalı, "Games" görevi yüksek GPU/CPU önceliği.' $true {
    $sp = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
    Set-Reg $sp 'SystemResponsiveness' 10
    Set-Reg $sp 'NetworkThrottlingIndex' -1          # 0xFFFFFFFF
    $g = "$sp\Tasks\Games"
    Set-Reg $g 'GPU Priority' 8
    Set-Reg $g 'Priority' 6
    Set-Reg $g 'Scheduling Category' 'High' 'String'
    Set-Reg $g 'SFIO Priority' 'High' 'String'
}
Twk 'Performans' 'Global zamanlayıcı çözünürlüğü' 'Oyun arka plandayken bile yüksek timer çözünürlüğü korunur. Çok az fazla güç harcar.' $false {
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel' 'GlobalTimerResolutionRequests' 1
}
Twk 'Performans' 'Xbox Game Bar kayıt / Game DVR kapat' 'Arka planda sürekli kayıt yapılmaz. Kayıt için NVIDIA App (ShadowPlay) kullanırsın.' $true {
    Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 0
}

# --- Edge ---
Twk 'Edge' 'Edge''i sustur (silmeden)' 'Arka planda çalışma, startup boost, Copilot kenar çubuğu, öneriler, "varsayılan yap" nag''i. Edge''de "kuruluşunuz tarafından yönetiliyor" yazar, normal.' $true {
    $e = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
    foreach ($n in 'StartupBoostEnabled', 'BackgroundModeEnabled', 'HubsSidebarEnabled', 'ShowRecommendationsEnabled',
                   'PersonalizationReportingEnabled', 'DefaultBrowserSettingEnabled') { Set-Reg $e $n 0 }
}

# --- Güvenlik ---
Twk 'Güvenlik' 'Defender''ı kapat (gerçek zamanlı + bulut)' 'ÖNCE Windows Güvenliği > Virüs ve tehdit koruması > Ayarları yönet > Kurcalama Koruması''nı KAPAT. Açıksa bu adım atlanır ve ayar sayfası açılır.' $false {
    $mp = Get-MpComputerStatus
    if ($mp -and $mp.IsTamperProtected) {
        Log '   ! Kurcalama Koruması açık, Defender atlandı. Kapatıp tekrar uygula.'
        Start-Process 'windowsdefender://threatsettings'
        return
    }
    Set-MpPreference -DisableRealtimeMonitoring $true -DisableBehaviorMonitoring $true -DisableIOAVProtection $true `
                     -DisableScriptScanning $true -DisableBlockAtFirstSeen $true -MAPSReporting Disabled -SubmitSamplesConsent NeverSend
    $r = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection'
    foreach ($n in 'DisableRealtimeMonitoring', 'DisableBehaviorMonitoring', 'DisableOnAccessProtection',
                   'DisableScanOnRealtimeEnable', 'DisableIOAVProtection') { Set-Reg $r $n 1 }
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet' 'SpynetReporting' 0
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet' 'SubmitSamplesConsent' 2
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications' 'DisableEnhancedNotifications' 1
}

# --- Diğer ---
Twk 'Diğer' 'OneDrive''ı kaldır' 'Dosyaların OneDrive klasöründe kalır, silinmez. Tekrar kurulması policy ile engellenir.' $false {
    Stop-Process -Name OneDrive -Force
    Wait-UI 2000
    $s = "$env:SystemRoot\System32\OneDriveSetup.exe"
    if (-not (Test-Path $s)) { $s = "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" }
    if (Test-Path $s) { Start-Process -FilePath $s -ArgumentList '/uninstall' -Wait }
    else { winget uninstall --id Microsoft.OneDrive --silent --accept-source-agreements | Out-Null }
    Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' 'DisableFileSyncNGSC' 1
    Set-Reg 'HKCU:\Software\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}' 'System.IsPinnedToNameSpaceTree' 0
}
Twk 'Diğer' 'Windows Sandbox''ı etkinleştir' 'Sadece Pro/Enterprise. Yeniden başlatma ister.' $false {
    Enable-WindowsOptionalFeature -Online -FeatureName 'Containers-DisposableClientVM' -All -NoRestart | Out-Null
}
Twk 'Diğer' 'WSL''i etkinleştir' 'Yeniden başlattıktan sonra "wsl --install" ile dağıtım kurarsın.' $false {
    Enable-WindowsOptionalFeature -Online -FeatureName 'Microsoft-Windows-Subsystem-Linux' -All -NoRestart | Out-Null
    Enable-WindowsOptionalFeature -Online -FeatureName 'VirtualMachinePlatform' -All -NoRestart | Out-Null
}
)

# ---------- Kurulacak uygulamalar (ayarlardan sonraki ekran) ----------
function Get-InstalledNames {
    @(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                       'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
                       'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' |
      Where-Object { $_.DisplayName } | ForEach-Object { $_.DisplayName })
}
function Test-Installed($i, $names) {
    if ($i.Path -and (Test-Path $i.Path)) { return $true }
    return [bool]($names | Where-Object { $_ -match $i.Rx })
}
function Install-Winget([string]$id) {
    if (-not (Get-Command winget)) {
        Log '   ! winget bu sistemde yok (Store''dan "Uygulama Yükleyici"yi güncelle), atlandı'; return
    }
    Log "   winget ile kuruluyor: $id (birkaç dakika sürebilir)"
    $p = Start-Process winget -ArgumentList "install --id $id --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity" `
                      -WindowStyle Hidden -PassThru
    while ($p -and -not $p.HasExited) { Wait-UI 500 }
    if ($p) {
        $hex = '0x{0:X8}' -f $p.ExitCode
        $why = switch ($hex) {
            '0x00000000' { 'başarılı' }
            '0x8A150011' { 'indirilen dosyanın hash''i winget kaydıyla tutmadı (paket güncel değil)' }
            '0x8A15002B' { 'zaten kurulu ve güncel' }
            '0x8A150014' { 'paket bulunamadı' }
            '0x8A150101' { 'kurulum başka bir kurulum bitene kadar bekliyor' }
            default      { 'ayrıntı için %LOCALAPPDATA%\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\DiagOutputDir' }
        }
        Log "   winget çıkış kodu: $hex ($why)"
    }
}
# Klasik programı kaldırır: varsa sessiz komut, MSI ise msiexec /x /qn, yoksa programın kendi kaldırıcısı (pencere açabilir)
function Uninstall-Win32($p) {
    $cmd = if ($p.Quiet) { $p.Quiet } else { $p.Uninstall }
    $cmd = [Environment]::ExpandEnvironmentVariables($cmd.Trim())
    if ($cmd -match 'msiexec' -and $cmd -match '\{[0-9A-Fa-f\-]{36}\}') {
        $exe = 'msiexec.exe'; $arg = "/x $($Matches[0]) /qn /norestart"
    } elseif ($cmd -match '^"([^"]+)"\s*(.*)$') {
        $exe = $Matches[1]; $arg = $Matches[2]
    } elseif ($cmd -match '^(.+?\.exe)\s*(.*)$') {
        $exe = $Matches[1]; $arg = $Matches[2]
    } else { $exe = $cmd; $arg = '' }
    Log "   çalıştırılıyor: $exe $arg"
    $p2 = if ($arg) { Start-Process -FilePath $exe -ArgumentList $arg -PassThru } else { Start-Process -FilePath $exe -PassThru }
    $deadline = (Get-Date).AddMinutes(15)
    while ($p2 -and -not $p2.HasExited -and (Get-Date) -lt $deadline) { Wait-UI 500 }
    # Bazı kaldırıcılar kopyasını başlatıp hemen çıkar; kayıt silinene kadar biraz bekle
    $wait = (Get-Date).AddSeconds(20)
    while ((Get-InstalledNames) -contains $p.Id -and (Get-Date) -lt $wait) { Wait-UI 1000 }
}
function Install-NvidiaApp {
    $fallback = 'https://us.download.nvidia.com/nvapp/client/11.0.9.565/NVIDIA_app_v11.0.9.565.exe'
    $url = $null
    try {
        $page = Invoke-WebRequest -Uri 'https://www.nvidia.com/en-us/software/nvidia-app/' -UseBasicParsing `
                                  -UserAgent 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)' -ErrorAction Stop
        $mm = [regex]::Match($page.Content, 'https://us\.download\.nvidia\.com/nvapp/client/[\d\.]+/NVIDIA_app_v[\d\.]+\.exe')
        if ($mm.Success) { $url = $mm.Value }
    } catch { }
    if (-not $url) { $url = $fallback; Log '   güncel link bulunamadı, yedek link kullanılıyor' }
    Log "   indirme linki: $url"

    $exe = Join-Path $env:TEMP 'NVIDIA_app_setup.exe'
    Log '   indiriliyor...'
    $job = Start-Job -ScriptBlock {
        param($u, $o)
        $ProgressPreference = 'SilentlyContinue'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $u -OutFile $o -UseBasicParsing -ErrorAction Stop
    } -ArgumentList $url, $exe
    while ($job.State -eq 'Running') { Wait-UI 300 }
    $jobErr = $null
    Receive-Job -Job $job -ErrorVariable jobErr | Out-Null
    Remove-Job -Job $job -Force

    if (-not (Test-Path $exe) -or (Get-Item $exe).Length -lt 10MB) {
        Log "   ! indirme başarısız: $jobErr"
        Start-Process 'https://www.nvidia.com/en-us/software/nvidia-app/'
        return
    }
    $sig = Get-AuthenticodeSignature -FilePath $exe
    if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notlike '*NVIDIA*') {
        Log "   ! dosya imzası geçersiz ($($sig.Status)), kurulmadı"
        return
    }
    Log '   imza doğrulandı (NVIDIA), kuruluyor... (birkaç dakika sürebilir)'
    $p = Start-Process -FilePath $exe -ArgumentList '/s' -PassThru
    $deadline = (Get-Date).AddMinutes(15)
    while ($p -and -not $p.HasExited -and (Get-Date) -lt $deadline) { Wait-UI 500 }
    if ($p -and $p.HasExited) { Log "   kurulum bitti (çıkış kodu: $($p.ExitCode))" }
    else { Log '   ! kurulum 15 dakikada bitmedi, arka planda devam ediyor olabilir' }
    Remove-Item $exe -Force
}

# Chrome winget'ten kurulmaz: Google hep aynı adresten en son sürümü verdiği için winget'in kayıtlı hash'i
# sık sık tutmuyor (0x8a150011). Resmi MSI indirilip Google imzası doğrulanarak kurulur.
function Install-Chrome {
    $msi = Join-Path $env:TEMP 'googlechromestandaloneenterprise64.msi'
    Log '   Google''ın resmi sitesinden indiriliyor (~170 MB)...'
    $job = Start-Job -ScriptBlock {
        param($u, $o)
        $ProgressPreference = 'SilentlyContinue'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $u -OutFile $o -UseBasicParsing -ErrorAction Stop
    } -ArgumentList 'https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi', $msi
    while ($job.State -eq 'Running') { Wait-UI 300 }
    $jobErr = $null
    Receive-Job -Job $job -ErrorVariable jobErr | Out-Null
    Remove-Job -Job $job -Force

    if (-not (Test-Path $msi) -or (Get-Item $msi).Length -lt 50MB) {
        Log "   ! indirme başarısız: $jobErr"
        Start-Process 'https://www.google.com/chrome/'
        return
    }
    $sig = Get-AuthenticodeSignature -FilePath $msi
    if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notlike '*Google*') {
        Log "   ! dosya imzası geçersiz ($($sig.Status)), kurulmadı"
        Remove-Item $msi -Force
        return
    }
    Log '   imza doğrulandı (Google), kuruluyor...'
    $p = Start-Process -FilePath 'msiexec.exe' -ArgumentList "/i `"$msi`" /qn /norestart" -PassThru
    $deadline = (Get-Date).AddMinutes(15)
    while ($p -and -not $p.HasExited -and (Get-Date) -lt $deadline) { Wait-UI 500 }
    if ($p -and $p.HasExited) { Log "   kurulum bitti (çıkış kodu: $($p.ExitCode))" }
    Remove-Item $msi -Force
}

# Custom doluysa winget yerine o fonksiyon çalışır
function Inst($Name, $Desc, $Rx, $WingetId, $Path, $Custom) {
    [pscustomobject]@{ Name = $Name; Desc = $Desc; Rx = $Rx; WingetId = $WingetId; Path = $Path; Custom = $Custom; CB = $null }
}
$Installs = @(
    Inst 'NVIDIA App' 'Sürücü güncellemeleri, ShadowPlay kayıt, oyun ayarları. Resmi siteden indirilir, NVIDIA imzası doğrulanıp sessiz kurulur.' '^NVIDIA app' $null $null 'Install-NvidiaApp'
    Inst 'Discord' 'Sesli/yazılı sohbet.' '^Discord$' 'Discord.Discord' "$env:LOCALAPPDATA\Discord\Update.exe"
    Inst 'Opera' 'Opera tarayıcısı (Opera Stable).' '^Opera Stable' 'Opera.Opera' $null
    Inst 'Google Chrome' 'Google''ın tarayıcısı. Resmi siteden indirilir, Google imzası doğrulanıp sessiz kurulur.' '^Google Chrome$' $null $null 'Install-Chrome'
    Inst 'Steam' 'Valve oyun platformu.' '^Steam$' 'Valve.Steam' $null
    Inst 'Logitech G HUB' 'Logitech mouse/klavye/kulaklık ayar yazılımı.' '^Logitech G HUB' 'Logitech.GHUB' $null
)

# ---------- Silinebilir uygulamalar ----------
function App($Id, $Name, $Def) { [pscustomobject]@{ Id = $Id; Name = $Name; Def = [bool]$Def; CB = $null } }
$Apps = @(
    App 'Microsoft.BingNews'                      'Microsoft Haberler'                $true
    App 'Microsoft.BingWeather'                   'Hava Durumu'                       $true
    App 'Microsoft.BingSearch'                    'Bing Arama'                        $true
    App 'Microsoft.GetHelp'                       'Yardım Al'                         $true
    App 'Microsoft.Getstarted'                    'İpuçları'                          $true
    App 'Microsoft.MicrosoftSolitaireCollection'  'Solitaire Collection'              $true
    App 'Microsoft.MicrosoftOfficeHub'            'Microsoft 365 (Office) uygulaması' $true
    App 'Microsoft.People'                        'Kişiler'                           $true
    App 'Microsoft.PowerAutomateDesktop'          'Power Automate'                    $true
    App 'Microsoft.Todos'                         'Microsoft To Do'                   $true
    App 'Microsoft.WindowsFeedbackHub'            'Geri Bildirim Merkezi'             $true
    App 'Microsoft.WindowsMaps'                   'Haritalar'                         $true
    App 'Microsoft.ZuneVideo'                     'Filmler ve TV'                     $true
    App 'Microsoft.549981C3F5F10'                 'Cortana'                           $true
    App 'Microsoft.Copilot'                       'Copilot'                           $true
    App 'Microsoft.OutlookForWindows'             'Outlook (yeni)'                    $true
    App 'Microsoft.Windows.DevHome'               'Dev Home'                          $true
    App 'Microsoft.MicrosoftJournal'              'Journal'                           $true
    App 'Microsoft.Edge.GameAssist'               'Edge Game Assist'                  $true
    App 'Clipchamp.Clipchamp'                     'Clipchamp'                         $true
    App 'MicrosoftCorporationII.MicrosoftFamily'  'Microsoft Family'                  $true
    App 'MSTeams'                                 'Teams'                             $true
    App 'MicrosoftTeams'                          'Teams (eski)'                      $true
    App '7EE7776C.LinkedInforWindows'             'LinkedIn'                          $true
    App 'Microsoft.YourPhone'                     'Telefon Bağlantısı'                $false
    App 'Microsoft.MicrosoftStickyNotes'          'Yapışkan Notlar'                   $false
    App 'Microsoft.WindowsAlarms'                 'Saat'                              $false
    App 'Microsoft.WindowsSoundRecorder'          'Ses Kaydedici'                     $false
    App 'Microsoft.WindowsCamera'                 'Kamera'                            $false
    App 'Microsoft.ZuneMusic'                     'Medya Oynatıcı'                    $false
    App 'MicrosoftCorporationII.QuickAssist'      'Hızlı Yardım'                      $false
    App 'Microsoft.GamingApp'                     'Xbox uygulaması'                   $false
    App 'Microsoft.XboxApp'                       'Xbox Console Companion'            $false
    App 'Microsoft.XboxGamingOverlay'             'Xbox Game Bar'                     $false
    App 'Microsoft.XboxGameOverlay'               'Xbox Game Overlay'                 $false
    App 'Microsoft.XboxSpeechToTextOverlay'       'Xbox Konuşmadan Metne'             $false
)

# ---------- Statik kontrol: scriptteki her komut ve parametre bu sistemde var mı? ----------
function Test-ScriptCode {
    $script:LogTarget.Clear()
    Log "> Kod kontrolü: $PSCommandPath"
    $tokens = $null; $errs = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($PSCommandPath, [ref]$tokens, [ref]$errs)
    if ($errs.Count) {
        foreach ($e in $errs) { Log "   ! SÖZDİZİMİ satır $($e.Extent.StartLineNumber): $($e.Message)" }
    } else { Log '   sözdizimi: hatasız' }

    $ownFns = @($ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) |
                ForEach-Object { $_.Name })
    $cmds = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true)
    $providerCmds = 'New-ItemProperty', 'Set-ItemProperty', 'Get-ItemProperty', 'New-Item', 'Remove-Item', 'Get-Item', 'Test-Path'
    $problems = 0; $checked = 0
    foreach ($c in $cmds) {
        $name = $c.GetCommandName()
        if (-not $name -or $ownFns -contains $name) { continue }
        $line = $c.Extent.StartLineNumber
        $name = $name -replace '^Microsoft\.PowerShell\.Management\\', ''
        if ($providerCmds -contains $name) { $gc = Get-Command -Name $name -ArgumentList 'HKCU:\Software' }
        else { $gc = Get-Command -Name $name }
        $checked++
        if (-not $gc) { Log "   ! satır ${line}: '$name' komutu bu sistemde YOK"; $problems++; continue }
        if ($gc -is [System.Management.Automation.ApplicationInfo]) { continue }
        if ($gc -is [System.Management.Automation.AliasInfo]) { $gc = $gc.ResolvedCommand }
        $valid = @{}
        foreach ($p in $gc.Parameters.Values) { $valid[$p.Name] = 1; foreach ($al in $p.Aliases) { $valid[$al] = 1 } }
        foreach ($el in $c.CommandElements) {
            if ($el -is [System.Management.Automation.Language.CommandParameterAst]) {
                if (-not $valid.ContainsKey($el.ParameterName)) {
                    Log "   ! satır ${line}: '$name' komutunda -$($el.ParameterName) parametresi YOK"; $problems++
                }
            }
        }
    }
    Log "   $checked komut kontrol edildi, $($Tweaks.Count) ayar, $($Apps.Count) uygulama tanımlı"
    if ($problems) { Log "SONUÇ: $problems sorun bulundu, ekran görüntüsünü at." }
    else { Log 'SONUÇ: tüm komutlar ve parametreler bu Windows''ta mevcut.' }
}

# ---------- Öneri seviyeleri: yeşil = önerilen, sarı = isteğe bağlı, kırmızı = dikkat ----------
$riskyTweaks = @('Defender''ı kapat*', 'OneDrive''ı kaldır')
$riskyApps   = @('Microsoft.GamingApp', 'Microsoft.XboxGamingOverlay', 'Microsoft.XboxGameOverlay')
foreach ($t in $Tweaks) {
    $lvl = if ($riskyTweaks | Where-Object { $t.Name -like $_ }) { 'red' } elseif ($t.Def) { 'green' } else { 'yellow' }
    $t | Add-Member -NotePropertyName Lvl -NotePropertyValue $lvl
    $t | Add-Member -NotePropertyName Row -NotePropertyValue $null
}
foreach ($a in $Apps) {
    $lvl = if ($riskyApps -contains $a.Id) { 'red' } elseif ($a.Def) { 'green' } else { 'yellow' }
    $a | Add-Member -NotePropertyName Lvl -NotePropertyValue $lvl
    $a | Add-Member -NotePropertyName Row -NotePropertyValue $null
}

# ---------- Arayüz (WPF) ----------
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Drawing
Add-Type -Namespace W11 -Name Dwm -MemberDefinition @'
[DllImport("dwmapi.dll")] public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
'@

$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Win11 Debloat Ozzie" Width="1220" Height="830" MinWidth="1000" MinHeight="680"
        WindowStartupLocation="CenterScreen" WindowStyle="None" ResizeMode="CanResize"
        Background="{DynamicResource AppBg}" Foreground="{DynamicResource Fg}"
        FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="13" UseLayoutRounding="True">
  <WindowChrome.WindowChrome>
    <WindowChrome CaptionHeight="44" ResizeBorderThickness="6" GlassFrameThickness="0" CornerRadius="0" UseAeroCaptionButtons="False"/>
  </WindowChrome.WindowChrome>
  <Window.Resources>
    <FontFamily x:Key="Icons">Segoe Fluent Icons, Segoe MDL2 Assets</FontFamily>

    <Style x:Key="Card" TargetType="Border">
      <Setter Property="Background" Value="{DynamicResource CardBg}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource CardBorder}"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="CornerRadius" Value="6"/>
      <Setter Property="Padding" Value="16"/>
    </Style>

    <Style x:Key="Primary" TargetType="Button">
      <Setter Property="Foreground" Value="{DynamicResource AccentFg}"/>
      <Setter Property="Background" Value="{DynamicResource Accent}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource Accent}"/>
      <Setter Property="FontSize" Value="14"/>
      <Setter Property="Height" Value="36"/>
      <Setter Property="MinWidth" Value="120"/>
      <Setter Property="Padding" Value="16,0"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" CornerRadius="4" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}"
                    BorderThickness="1" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="B" Property="Opacity" Value="0.88"/></Trigger>
              <Trigger Property="IsPressed" Value="True"><Setter TargetName="B" Property="Opacity" Value="0.72"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter TargetName="B" Property="Opacity" Value="0.4"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="Secondary" TargetType="Button" BasedOn="{StaticResource Primary}">
      <Setter Property="Foreground" Value="{DynamicResource Fg}"/>
      <Setter Property="Background" Value="{DynamicResource SecBg}"/>
      <Setter Property="BorderBrush" Value="{DynamicResource CardBorder}"/>
    </Style>
    <Style x:Key="Small" TargetType="Button" BasedOn="{StaticResource Secondary}">
      <Setter Property="Height" Value="34"/>
      <Setter Property="MinWidth" Value="0"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="Padding" Value="14,0"/>
      <Setter Property="Margin" Value="8,0,0,0"/>
    </Style>

    <Style x:Key="Link" TargetType="Button">
      <Setter Property="Foreground" Value="{DynamicResource Accent}"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border Background="Transparent" Padding="6,2"><ContentPresenter/></Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter Property="Opacity" Value="0.7"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="Caption" TargetType="Button">
      <Setter Property="Width" Value="46"/>
      <Setter Property="Height" Value="44"/>
      <Setter Property="FontFamily" Value="{StaticResource Icons}"/>
      <Setter Property="FontSize" Value="10"/>
      <Setter Property="Foreground" Value="{DynamicResource Fg}"/>
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="WindowChrome.IsHitTestVisibleInChrome" Value="True"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" Background="Transparent"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="B" Property="Background" Value="{DynamicResource Hover}"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="CaptionClose" TargetType="Button" BasedOn="{StaticResource Caption}">
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" Background="Transparent"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="Background" Value="#C42B1C"/>
                <Setter Property="Foreground" Value="White"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Güneş / ay kaydırmalı tema anahtarı -->
    <Style x:Key="ThemeSwitch" TargetType="ToggleButton">
      <Setter Property="Width" Value="64"/>
      <Setter Property="Height" Value="30"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="WindowChrome.IsHitTestVisibleInChrome" Value="True"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ToggleButton">
            <Grid>
              <Border CornerRadius="15" Background="{DynamicResource InputBg}" BorderBrush="{DynamicResource CardBorder}" BorderThickness="1"/>
              <TextBlock Text="&#xE706;" FontFamily="{StaticResource Icons}" FontSize="13" Foreground="{DynamicResource FgDim}"
                         HorizontalAlignment="Left" VerticalAlignment="Center" Margin="10,0,0,0"/>
              <TextBlock Text="&#xE708;" FontFamily="{StaticResource Icons}" FontSize="13" Foreground="{DynamicResource FgDim}"
                         HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,10,0"/>
              <Border x:Name="Knob" Width="24" Height="24" CornerRadius="12" Background="{DynamicResource Accent}"
                      HorizontalAlignment="Left" VerticalAlignment="Center" Margin="3,0,0,0">
                <Border.RenderTransform><TranslateTransform X="0"/></Border.RenderTransform>
                <Grid>
                  <TextBlock x:Name="Sun" Text="&#xE706;" FontFamily="{StaticResource Icons}" FontSize="13" Foreground="{DynamicResource AccentFg}"
                             HorizontalAlignment="Center" VerticalAlignment="Center"/>
                  <TextBlock x:Name="Moon" Text="&#xE708;" FontFamily="{StaticResource Icons}" FontSize="13" Foreground="{DynamicResource AccentFg}"
                             HorizontalAlignment="Center" VerticalAlignment="Center" Opacity="0"/>
                </Grid>
              </Border>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Trigger.EnterActions>
                  <BeginStoryboard>
                    <Storyboard>
                      <DoubleAnimation Storyboard.TargetName="Knob" Storyboard.TargetProperty="(UIElement.RenderTransform).(TranslateTransform.X)" To="34" Duration="0:0:0.25">
                        <DoubleAnimation.EasingFunction><CubicEase EasingMode="EaseOut"/></DoubleAnimation.EasingFunction>
                      </DoubleAnimation>
                      <DoubleAnimation Storyboard.TargetName="Sun" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.2"/>
                      <DoubleAnimation Storyboard.TargetName="Moon" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.2"/>
                    </Storyboard>
                  </BeginStoryboard>
                </Trigger.EnterActions>
                <Trigger.ExitActions>
                  <BeginStoryboard>
                    <Storyboard>
                      <DoubleAnimation Storyboard.TargetName="Knob" Storyboard.TargetProperty="(UIElement.RenderTransform).(TranslateTransform.X)" To="0" Duration="0:0:0.25">
                        <DoubleAnimation.EasingFunction><CubicEase EasingMode="EaseOut"/></DoubleAnimation.EasingFunction>
                      </DoubleAnimation>
                      <DoubleAnimation Storyboard.TargetName="Sun" Storyboard.TargetProperty="Opacity" To="1" Duration="0:0:0.2"/>
                      <DoubleAnimation Storyboard.TargetName="Moon" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.2"/>
                    </Storyboard>
                  </BeginStoryboard>
                </Trigger.ExitActions>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="CheckBox">
      <Setter Property="Foreground" Value="{DynamicResource Fg}"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FocusVisualStyle" Value="{x:Null}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <Grid Background="Transparent">
              <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
              <Border x:Name="Box" Width="18" Height="18" CornerRadius="4" BorderThickness="1" Margin="0,1,0,0"
                      VerticalAlignment="{TemplateBinding VerticalContentAlignment}"
                      BorderBrush="{DynamicResource FgDim}" Background="{DynamicResource InputBg}">
                <TextBlock x:Name="Mark" Text="&#xE73E;" FontFamily="{StaticResource Icons}" FontSize="11" Foreground="{DynamicResource AccentFg}"
                           HorizontalAlignment="Center" VerticalAlignment="Center" Visibility="Collapsed"/>
              </Border>
              <ContentPresenter Grid.Column="1" Margin="8,0,0,0" VerticalAlignment="Center"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Box" Property="BorderBrush" Value="{DynamicResource Accent}"/></Trigger>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="Box" Property="Background" Value="{DynamicResource Accent}"/>
                <Setter TargetName="Box" Property="BorderBrush" Value="{DynamicResource Accent}"/>
                <Setter TargetName="Mark" Property="Visibility" Value="Visible"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.45"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="Search" TargetType="TextBox">
      <Setter Property="Foreground" Value="{DynamicResource Fg}"/>
      <Setter Property="CaretBrush" Value="{DynamicResource Fg}"/>
      <Setter Property="Height" Value="34"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TextBox">
            <Border x:Name="B" CornerRadius="4" Background="{DynamicResource InputBg}" BorderBrush="{DynamicResource CardBorder}" BorderThickness="1,1,1,2">
              <Grid Margin="10,0">
                <TextBlock Text="&#xE721;" FontFamily="{StaticResource Icons}" FontSize="13" Foreground="{DynamicResource FgDim}" VerticalAlignment="Center"/>
                <TextBlock x:Name="Hint" Text="{TemplateBinding Tag}" Foreground="{DynamicResource FgDim}" Margin="26,0,0,0"
                           VerticalAlignment="Center" Visibility="Collapsed" IsHitTestVisible="False"/>
                <ScrollViewer x:Name="PART_ContentHost" Margin="24,0,0,0" VerticalAlignment="Center"/>
              </Grid>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="Text" Value=""><Setter TargetName="Hint" Property="Visibility" Value="Visible"/></Trigger>
              <Trigger Property="IsKeyboardFocused" Value="True"><Setter TargetName="B" Property="BorderBrush" Value="{DynamicResource Accent}"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="LogBox" TargetType="TextBox">
      <Setter Property="IsReadOnly" Value="True"/>
      <Setter Property="FontFamily" Value="Cascadia Mono, Consolas"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="Foreground" Value="{DynamicResource Fg}"/>
      <Setter Property="TextWrapping" Value="Wrap"/>
      <Setter Property="ScrollViewer.VerticalScrollBarVisibility" Value="Auto"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="TextBox">
            <Border CornerRadius="6" Background="{DynamicResource InputBg}" BorderBrush="{DynamicResource CardBorder}" BorderThickness="1" Padding="10,8">
              <ScrollViewer x:Name="PART_ContentHost"/>
            </Border>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="ProgressBar">
      <Setter Property="Height" Value="6"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ProgressBar">
            <Grid>
              <Border x:Name="PART_Track" CornerRadius="3" Background="{DynamicResource CardBorder}"/>
              <Border x:Name="PART_Indicator" CornerRadius="3" Background="{DynamicResource Accent}" HorizontalAlignment="Left"/>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style TargetType="ScrollBar">
      <Setter Property="Width" Value="8"/>
      <Setter Property="MinWidth" Value="8"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ScrollBar">
            <Track x:Name="PART_Track" IsDirectionReversed="True">
              <Track.DecreaseRepeatButton><RepeatButton Command="ScrollBar.PageUpCommand" Opacity="0" Focusable="False"/></Track.DecreaseRepeatButton>
              <Track.IncreaseRepeatButton><RepeatButton Command="ScrollBar.PageDownCommand" Opacity="0" Focusable="False"/></Track.IncreaseRepeatButton>
              <Track.Thumb>
                <Thumb>
                  <Thumb.Template>
                    <ControlTemplate TargetType="Thumb"><Border CornerRadius="4" Background="{DynamicResource Thumb}"/></ControlTemplate>
                  </Thumb.Template>
                </Thumb>
              </Track.Thumb>
            </Track>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <Border x:Name="Root" Background="{DynamicResource AppBg}">
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="44"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="72"/>
      </Grid.RowDefinitions>

      <!-- Başlık çubuğu -->
      <Grid Grid.Row="0">
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="16,0,0,0">
          <TextBlock Text="&#xE713;" FontFamily="{StaticResource Icons}" FontSize="15" Foreground="{DynamicResource Accent}" VerticalAlignment="Center"/>
          <TextBlock Text="Win11 Debloat Ozzie" Margin="10,0,0,0" FontSize="12" VerticalAlignment="Center"/>
        </StackPanel>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
          <ToggleButton x:Name="ThemeToggle" Style="{StaticResource ThemeSwitch}" Margin="0,0,14,0" VerticalAlignment="Center" ToolTip="Açık / koyu tema"/>
          <Button x:Name="BtnMin" Style="{StaticResource Caption}" Content="&#xE921;"/>
          <Button x:Name="BtnMax" Style="{StaticResource Caption}" Content="&#xE922;"/>
          <Button x:Name="BtnClose" Style="{StaticResource CaptionClose}" Content="&#xE8BB;"/>
        </StackPanel>
      </Grid>

      <Grid Grid.Row="1" Margin="32,8,32,0">
        <!-- 0: Başlangıç -->
        <Grid x:Name="Page0">
          <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center" Width="720">
            <Border Width="96" Height="96" CornerRadius="24" Background="{DynamicResource Accent}" HorizontalAlignment="Center">
              <TextBlock Text="&#xE713;" FontFamily="{StaticResource Icons}" FontSize="46" Foreground="{DynamicResource AccentFg}"
                         HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <TextBlock Text="Win11 Debloat Ozzie" FontSize="38" FontWeight="SemiBold" HorizontalAlignment="Center" Margin="0,22,0,4"/>
            <TextBlock Text="Windows 11'i sadeleştir, gizliliğini koru, oyun performansını artır." FontSize="16"
                       Foreground="{DynamicResource FgDim}" HorizontalAlignment="Center"/>
            <Border Style="{StaticResource Card}" Margin="0,32,0,0" Padding="24,16" HorizontalAlignment="Center">
              <StackPanel x:Name="SysInfo" Orientation="Horizontal"/>
            </Border>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,28,0,0">
              <Button x:Name="BtnStart" Style="{StaticResource Primary}" Width="220" Height="46" FontSize="16" Content="Başla"/>
              <Button x:Name="BtnCheck" Style="{StaticResource Secondary}" Width="220" Height="46" FontSize="16" Margin="12,0,0,0" Content="Kodu kontrol et"/>
            </StackPanel>
            <TextBox x:Name="CheckLog" Style="{StaticResource LogBox}" Height="150" Margin="0,24,0,0" Visibility="Collapsed"/>
          </StackPanel>
        </Grid>

        <!-- 1: Uygulama kaldırma -->
        <Grid x:Name="Page1" Visibility="Collapsed">
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
          <StackPanel Margin="0,4,0,16">
            <TextBlock Text="Uygulamaları kaldır" FontSize="26" FontWeight="SemiBold"/>
            <TextBlock FontSize="14" Foreground="{DynamicResource FgDim}" Margin="0,4,0,0" TextWrapping="Wrap"
                       Text="Sadece PC'nde yüklü olanlar listelenir. Store, Uygulama Yükleyici, Xbox Identity Provider ve Xbox TCUI bilerek listede yok (oyun girişleri ve kurulum bozulmasın)."/>
          </StackPanel>
          <DockPanel Grid.Row="1" Margin="0,0,0,12" LastChildFill="False">
            <TextBox x:Name="AppSearch" Style="{StaticResource Search}" Tag="Uygulama ara..." Width="300" DockPanel.Dock="Left"/>
            <Button x:Name="AppRec" Style="{StaticResource Small}" Content="Önerilenleri seç" DockPanel.Dock="Left"/>
            <Button x:Name="AppClear" Style="{StaticResource Small}" Content="Temizle" DockPanel.Dock="Left"/>
            <TextBlock x:Name="AppCount" Foreground="{DynamicResource FgDim}" VerticalAlignment="Center" Margin="16,0,0,0" DockPanel.Dock="Left"/>
            <StackPanel x:Name="Legend1" Orientation="Horizontal" VerticalAlignment="Center" DockPanel.Dock="Right"/>
          </DockPanel>
          <Border Grid.Row="2" Style="{StaticResource Card}" Padding="8" Margin="0,0,0,16">
            <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
              <StackPanel>
                <TextBlock Text="Önerilen kaldırılabilir uygulamalar" FontSize="16" FontWeight="SemiBold" Margin="10,6,0,0"/>
                <TextBlock FontSize="12" Foreground="{DynamicResource FgDim}" Margin="10,2,10,4" TextWrapping="Wrap"
                           Text="Windows ile gelen gereksiz Microsoft uygulamaları."/>
                <TextBlock x:Name="AppEmpty" Visibility="Collapsed" Margin="10,6,10,6" FontSize="13" Foreground="{DynamicResource FgDim}"
                           Text="Bu listedeki uygulamaların hiçbiri yüklü değil."/>
                <StackPanel x:Name="AppGrid"/>

                <Border BorderThickness="0,1,0,0" BorderBrush="{DynamicResource CardBorder}" Margin="10,18,10,0" Padding="0,14,0,0">
                  <CheckBox x:Name="ShowOther">
                    <StackPanel>
                      <TextBlock Text="Bilgisayardaki diğer programları da göster" FontSize="14" FontWeight="SemiBold"/>
                      <TextBlock Text="Store uygulamaları ve klasik programlar listelenir. Hiçbiri seçili gelmez, silmek istediklerini kendin işaretlersin."
                                 FontSize="12" Foreground="{DynamicResource FgDim}" Margin="0,2,0,0" TextWrapping="Wrap"/>
                    </StackPanel>
                  </CheckBox>
                </Border>

                <StackPanel x:Name="OtherSection" Visibility="Collapsed">
                <TextBlock Text="Diğer Store uygulamaları" FontSize="16" FontWeight="SemiBold" Margin="10,22,0,0"/>
                <TextBlock FontSize="12" Foreground="{DynamicResource FgDim}" Margin="10,2,10,4" TextWrapping="Wrap"
                           Text="Bilgisayarındaki diğer kaldırılabilir Store uygulamaları. Hiçbiri varsayılan seçili gelmez; sürücü yazılımları ve kodekler kırmızı işaretlidir."/>
                <StackPanel x:Name="StoreGrid"/>

                <TextBlock Text="Klasik programlar" FontSize="16" FontWeight="SemiBold" Margin="10,22,0,0"/>
                <TextBlock FontSize="12" Foreground="{DynamicResource FgDim}" Margin="10,2,10,4" TextWrapping="Wrap"
                           Text="Denetim Masası'ndaki programlar. Sessiz kaldırmayı desteklemeyenler kendi kaldırma penceresini açar, oradan onaylaman gerekir. Sürücüler, çalışma ortamları ve anti-cheat'ler kırmızı işaretlidir."/>
                <StackPanel x:Name="Win32Grid"/>
                </StackPanel>
              </StackPanel>
            </ScrollViewer>
          </Border>
        </Grid>

        <!-- 2: Ayarlar -->
        <Grid x:Name="Page2" Visibility="Collapsed">
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
          <StackPanel Margin="0,4,0,16">
            <TextBlock Text="Ayarlar" FontSize="26" FontWeight="SemiBold"/>
            <TextBlock FontSize="14" Foreground="{DynamicResource FgDim}" Margin="0,4,0,0" TextWrapping="Wrap"
                       Text="Gizlilik, reklamlar, AI özellikleri, görünüm ve oyun performansı. Önerilenler varsayılan olarak seçili gelir."/>
          </StackPanel>
          <DockPanel Grid.Row="1" Margin="0,0,0,12" LastChildFill="False">
            <TextBox x:Name="TweakSearch" Style="{StaticResource Search}" Tag="Ayar ara..." Width="300" DockPanel.Dock="Left"/>
            <Button x:Name="TweakRec" Style="{StaticResource Small}" Content="Önerilenleri seç" DockPanel.Dock="Left"/>
            <Button x:Name="TweakClear" Style="{StaticResource Small}" Content="Temizle" DockPanel.Dock="Left"/>
            <TextBlock x:Name="TweakCount" Foreground="{DynamicResource FgDim}" VerticalAlignment="Center" Margin="16,0,0,0" DockPanel.Dock="Left"/>
            <StackPanel x:Name="Legend2" Orientation="Horizontal" VerticalAlignment="Center" DockPanel.Dock="Right"/>
          </DockPanel>
          <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="0,0,10,0">
            <Grid>
              <Grid.ColumnDefinitions><ColumnDefinition/><ColumnDefinition/><ColumnDefinition/></Grid.ColumnDefinitions>
              <StackPanel x:Name="TCol0" Margin="0,0,8,0"/>
              <StackPanel x:Name="TCol1" Grid.Column="1" Margin="8,0,8,0"/>
              <StackPanel x:Name="TCol2" Grid.Column="2" Margin="8,0,0,0"/>
            </Grid>
          </ScrollViewer>
        </Grid>

        <!-- 3: Kurulacak uygulamalar -->
        <Grid x:Name="Page3" Visibility="Collapsed">
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
          <StackPanel Margin="0,4,0,16">
            <TextBlock Text="Kurulacak uygulamalar" FontSize="26" FontWeight="SemiBold"/>
            <TextBlock FontSize="14" Foreground="{DynamicResource FgDim}" Margin="0,4,0,0" TextWrapping="Wrap"
                       Text="Ayarlar uygulandıktan sonra sessizce kurulur. Zaten kurulu olanlar seçilemez."/>
          </StackPanel>
          <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
            <WrapPanel x:Name="InstWrap"/>
          </ScrollViewer>
        </Grid>

        <!-- 4: Özet -->
        <Grid x:Name="Page4" Visibility="Collapsed">
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
          <StackPanel Margin="0,4,0,16">
            <TextBlock Text="Özet" FontSize="26" FontWeight="SemiBold"/>
            <TextBlock FontSize="14" Foreground="{DynamicResource FgDim}" Margin="0,4,0,0" TextWrapping="Wrap"
                       Text="UYGULA'ya bastığında aşağıdakiler yapılacak. Değiştirmek için Geri ile dönebilirsin."/>
          </StackPanel>
          <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Padding="0,0,10,0">
            <StackPanel x:Name="SummaryPanel"/>
          </ScrollViewer>
        </Grid>

        <!-- 5: Uygulanıyor -->
        <Grid x:Name="Page5" Visibility="Collapsed">
          <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
          <StackPanel Margin="0,4,0,16">
            <TextBlock x:Name="RunTitle" Text="Uygulanıyor..." FontSize="26" FontWeight="SemiBold"/>
            <TextBlock x:Name="RunStep" FontSize="14" Foreground="{DynamicResource FgDim}" Margin="0,4,0,0" TextWrapping="Wrap"/>
          </StackPanel>
          <ProgressBar x:Name="RunBar" Grid.Row="1" Margin="0,0,0,16"/>
          <TextBox x:Name="RunLog" Grid.Row="2" Style="{StaticResource LogBox}" Margin="0,0,0,16"/>
        </Grid>
      </Grid>

      <!-- Alt gezinme çubuğu -->
      <Border Grid.Row="2" BorderThickness="0,1,0,0" BorderBrush="{DynamicResource CardBorder}" Background="{DynamicResource CardBg}">
        <Grid Margin="32,0">
          <Button x:Name="BtnBack" Style="{StaticResource Secondary}" HorizontalAlignment="Left" VerticalAlignment="Center" Content="Geri"/>
          <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
            <StackPanel x:Name="Dots" Orientation="Horizontal" HorizontalAlignment="Center"/>
            <TextBlock x:Name="StepLabel" FontSize="11" Foreground="{DynamicResource FgDim}" HorizontalAlignment="Center" Margin="0,8,0,0"/>
          </StackPanel>
          <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
            <!-- İmza: her ekranda sağ altta -->
            <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="0,0,20,0" ToolTip="Win11 Debloat Ozzie">
              <TextBlock Text="by" FontSize="11" Foreground="{DynamicResource FgDim}" VerticalAlignment="Bottom" Margin="0,0,6,5"/>
              <TextBlock Text="Ozzie" FontFamily="Segoe Script" FontSize="20" FontWeight="Bold" Foreground="{DynamicResource Accent}" VerticalAlignment="Center"/>
            </StackPanel>
            <Button x:Name="BtnNext" Style="{StaticResource Primary}" VerticalAlignment="Center" Content="İleri"/>
          </StackPanel>
        </Grid>
      </Border>
    </Grid>
  </Border>
</Window>
'@

$window = [Windows.Markup.XamlReader]::Parse($xaml)
$ui = @{}
foreach ($m in [regex]::Matches($xaml, 'x:Name="(\w+)"')) {
    $n = $m.Groups[1].Value
    $el = $window.FindName($n)
    if ($el) { $ui[$n] = $el }
}

# ---------- Tema ----------
$Themes = @{
    Dark  = @{ AppBg = '#202020'; CardBg = '#2B2B2B'; CardBorder = '#3A3A3A'; Fg = '#FFFFFF'; FgDim = '#A8A8A8'; Accent = '#4CC2FF'
               AccentFg = '#000000'; SecBg = '#323232'; InputBg = '#1C1C1C'; Hover = '#3A3A3A'; Thumb = '#6E6E6E' }
    Light = @{ AppBg = '#F3F3F3'; CardBg = '#FFFFFF'; CardBorder = '#E0E0E0'; Fg = '#1B1B1B'; FgDim = '#5F5F5F'; Accent = '#0067C0'
               AccentFg = '#FFFFFF'; SecBg = '#FBFBFB'; InputBg = '#FFFFFF'; Hover = '#E9E9E9'; Thumb = '#A6A6A6' }
}
function Set-Theme([string]$name, [bool]$animate) {
    foreach ($k in $Themes[$name].Keys) {
        $c = [Windows.Media.ColorConverter]::ConvertFromString($Themes[$name][$k])
        $old = $window.Resources[$k]
        # ResourceDictionary eklenen fırçayı dondurur; animasyonu ÖNCE başlatınca fırça dondurulamaz.
        # Her geçişte eski renkten yeni renge giden yeni bir fırça konur.
        $from = if ($old) { $old.Color } else { $c }
        $ms = if ($animate -and $old) { 300 } else { 0 }
        $b = [Windows.Media.SolidColorBrush]::new($from)
        $an = [Windows.Media.Animation.ColorAnimation]::new($c, [Windows.Duration]::new([TimeSpan]::FromMilliseconds($ms)))
        $b.BeginAnimation([Windows.Media.SolidColorBrush]::ColorProperty, $an)
        $window.Resources[$k] = $b
    }
}
$startDark = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize').AppsUseLightTheme -eq 0
Set-Theme $(if ($startDark) { 'Dark' } else { 'Light' }) $false
$ui.ThemeToggle.IsChecked = $startDark
$ui.ThemeToggle.Add_Checked({ Set-Theme 'Dark' $true })
$ui.ThemeToggle.Add_Unchecked({ Set-Theme 'Light' $true })

# ---------- Eleman yardımcıları ----------
function Th($l, $t, $r, $b) { New-Object Windows.Thickness($l, $t, $r, $b) }
function New-Text([string]$text, [double]$size = 13, [string]$color = 'Fg', [string]$weight = 'Normal') {
    $tb = New-Object Windows.Controls.TextBlock
    $tb.Text = $text; $tb.FontSize = $size; $tb.TextWrapping = 'Wrap'
    $tb.FontWeight = [Windows.FontWeights]::$weight
    $tb.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, $color)
    return $tb
}
function New-Card {
    $c = New-Object Windows.Controls.Border
    $c.Style = $window.FindResource('Card')
    return $c
}
function New-Brush([string]$hex) { [Windows.Media.SolidColorBrush]::new([Windows.Media.ColorConverter]::ConvertFromString($hex)) }

$MarkInfo = @{
    green  = @('M5,0 A5,5 0 1 1 5,10 A5,5 0 1 1 5,0 Z', '#4CAF50', 'Önerilen', 'Önerilen: gönül rahatlığıyla uygulanabilir')
    yellow = @('M5,0 L10,5 L5,10 L0,5 Z', '#FFC107', 'İsteğe bağlı', 'İsteğe bağlı: ihtiyacına göre seç')
    red    = @('M5,0 L10,9.5 L0,9.5 Z', '#F44336', 'Dikkat', 'Dikkat: ne yaptığını biliyorsan seç')
}
function New-Marker([string]$lvl) {
    $p = New-Object Windows.Shapes.Path
    $p.Data = [Windows.Media.Geometry]::Parse($MarkInfo[$lvl][0])
    $p.Fill = New-Brush $MarkInfo[$lvl][1]
    $p.Width = 10; $p.Height = 10
    $p.ToolTip = $MarkInfo[$lvl][3]
    $p.VerticalAlignment = 'Top'; $p.Margin = Th 0 5 10 0
    return $p
}
function Add-Legend($panel) {
    foreach ($lvl in 'green', 'yellow', 'red') {
        $m = New-Marker $lvl; $m.Margin = Th 16 0 6 0; $m.VerticalAlignment = 'Center'
        [void]$panel.Children.Add($m)
        [void]$panel.Children.Add((New-Text $MarkInfo[$lvl][2] 12 'FgDim'))
    }
}

# İşaret + checkbox + açıklama satırı. Checkbox ve satır öğeye bağlanır.
function New-OptionRow($item, [string]$title, [string]$desc) {
    $g = New-Object Windows.Controls.Grid
    $c0 = New-Object Windows.Controls.ColumnDefinition; $c0.Width = [Windows.GridLength]::Auto
    [void]$g.ColumnDefinitions.Add($c0)
    [void]$g.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition))
    [void]$g.Children.Add((New-Marker $item.Lvl))
    $sp = New-Object Windows.Controls.StackPanel
    [Windows.Controls.Grid]::SetColumn($sp, 1)
    $cb = New-Object Windows.Controls.CheckBox
    $cb.Content = New-Text $title 13.5 'Fg' 'SemiBold'
    $cb.IsChecked = $item.Def
    $cb.Add_Checked({ Update-Counts }); $cb.Add_Unchecked({ Update-Counts })
    [void]$sp.Children.Add($cb)
    if ($desc) { $d = New-Text $desc 12 'FgDim'; $d.Margin = Th 26 2 0 0; [void]$sp.Children.Add($d) }
    [void]$g.Children.Add($sp)
    $item.CB = $cb; $item.Row = $g
    return $g
}
function Test-Match([string]$s, [string]$q) {
    return (-not $q) -or ($s -and $s.IndexOf($q, [StringComparison]::CurrentCultureIgnoreCase) -ge 0)
}

# ---------- Uygulama simgeleri ----------
function Get-FileImage([string]$path) {
    try {
        $bi = New-Object Windows.Media.Imaging.BitmapImage
        $bi.BeginInit(); $bi.CacheOption = 'OnLoad'; $bi.DecodePixelWidth = 64; $bi.UriSource = [Uri]$path; $bi.EndInit(); $bi.Freeze()
        return $bi
    } catch { return $null }
}
# Store uygulaması: paketin manifest'indeki logo (tercihen arka plansız 48px görev çubuğu simgesi)
function Get-AppxIcon($pkg) {
    if (-not $pkg -or -not $pkg.InstallLocation) { return $null }
    try {
        [xml]$m = Get-Content -LiteralPath (Join-Path $pkg.InstallLocation 'AppxManifest.xml') -Raw -ErrorAction Stop
        $rels = @()
        foreach ($app in @($m.Package.Applications.Application)) { if ($app.VisualElements.Square44x44Logo) { $rels += $app.VisualElements.Square44x44Logo } }
        if ($m.Package.Properties.Logo) { $rels += $m.Package.Properties.Logo }
        foreach ($rel in $rels) {
            $full = Join-Path $pkg.InstallLocation $rel
            $dir = Split-Path $full; $base = [IO.Path]::GetFileNameWithoutExtension($full)
            if (-not (Test-Path -LiteralPath $dir)) { continue }
            $files = @(Get-ChildItem -LiteralPath $dir -Filter "$base*.png" -ErrorAction SilentlyContinue)
            if (-not $files) { continue }
            $best = $files | Sort-Object -Descending -Property @{ Expression = {
                $n = $_.Name; $s = 0
                if ($n -match 'altform-unplated') { $s += 4 }
                if ($n -match 'targetsize-48') { $s += 3 } elseif ($n -match 'targetsize-(32|64)') { $s += 2 } elseif ($n -match 'scale-200') { $s += 1 }
                if ($n -match 'contrast|lightunplated') { $s -= 10 }
                $s } } | Select-Object -First 1
            $img = Get-FileImage $best.FullName
            if ($img) { return $img }
        }
    } catch { }
    return $null
}
# Klasik program: DisplayIcon kaydı, yoksa kaldırıcı exe'sinin simgesi
function Get-Win32Icon([string]$spec, [string]$uninstall) {
    $path = $null
    if ($spec) { $path = (($spec -replace '"', '') -replace ',\s*-?\d+\s*$', '').Trim() }
    if ((-not $path -or -not (Test-Path -LiteralPath $path)) -and $uninstall -and $uninstall -notmatch 'msiexec') {
        if ($uninstall -match '^"([^"]+\.exe)"' -or $uninstall -match '^(.+?\.exe)') { $path = $Matches[1] }
    }
    if (-not $path) { return $null }
    $path = [Environment]::ExpandEnvironmentVariables($path)
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    if ($path -match '\.(png|ico)$') { return Get-FileImage $path }
    try {
        $ico = [System.Drawing.Icon]::ExtractAssociatedIcon($path)
        $src = [System.Windows.Interop.Imaging]::CreateBitmapSourceFromHIcon($ico.Handle, [Windows.Int32Rect]::Empty,
                   [Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions())
        $src.Freeze(); $ico.Dispose()
        return $src
    } catch { return $null }
}
# Kurulacak uygulama: resmi sitenin simgesi (Google favicon servisi üzerinden, arka planda iner)
function Get-WebIcon([string]$siteUrl) {
    try {
        $bi = New-Object Windows.Media.Imaging.BitmapImage
        $bi.BeginInit()
        $bi.UriSource = [Uri]('https://www.google.com/s2/favicons?sz=64&domain_url=' + [Uri]::EscapeDataString($siteUrl))
        $bi.EndInit()
        return $bi
    } catch { return $null }
}
# Simge kutusu: simge yoksa (ya da inene kadar) baş harf gösterilir
function New-IconBox($src, [string]$name, [double]$size = 28) {
    $g = New-Object Windows.Controls.Grid
    $g.Width = $size; $g.Height = $size; $g.VerticalAlignment = 'Center'
    $ph = New-Object Windows.Controls.Border
    $ph.CornerRadius = New-Object Windows.CornerRadius(6)
    $ph.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'Hover')
    $letter = New-Text $(if ($name) { $name.Substring(0, 1).ToUpper() } else { '?' }) ($size * 0.5) 'FgDim' 'SemiBold'
    $letter.HorizontalAlignment = 'Center'; $letter.VerticalAlignment = 'Center'; $letter.TextWrapping = 'NoWrap'
    $ph.Child = $letter
    [void]$g.Children.Add($ph)
    if ($src) {
        $img = New-Object Windows.Controls.Image
        $img.Source = $src; $img.Width = $size; $img.Height = $size
        [Windows.Media.RenderOptions]::SetBitmapScalingMode($img, 'HighQuality')
        [void]$g.Children.Add($img)
        if ($src -is [Windows.Media.Imaging.BitmapImage] -and $src.IsDownloading) {
            $phRef = $ph
            $src.Add_DownloadCompleted({ $phRef.Visibility = 'Collapsed' }.GetNewClosure())
        } else { $ph.Visibility = 'Collapsed' }
    }
    return $g
}

# Kaldırma listesi satırı: işaret + checkbox + simge + ad + alt yazı, satırın tamamı tıklanabilir
function New-ListRow($item, [string]$title, [string]$desc, $icon) {
    $row = New-Object Windows.Controls.Border
    $row.BorderThickness = Th 0 0 0 1
    $row.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'CardBorder')
    $row.Padding = Th 12 8 12 8
    $row.Background = [Windows.Media.Brushes]::Transparent
    $row.Add_MouseEnter({ $this.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'Hover') })
    $row.Add_MouseLeave({ $this.Background = [Windows.Media.Brushes]::Transparent })

    $g = New-Object Windows.Controls.Grid
    $c0 = New-Object Windows.Controls.ColumnDefinition; $c0.Width = [Windows.GridLength]::Auto
    [void]$g.ColumnDefinitions.Add($c0)
    [void]$g.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition))
    $mk = New-Marker $item.Lvl; $mk.VerticalAlignment = 'Center'; $mk.Margin = Th 0 0 12 0
    [void]$g.Children.Add($mk)

    $content = New-Object Windows.Controls.StackPanel
    $content.Orientation = 'Horizontal'
    [void]$content.Children.Add((New-IconBox $icon $title 28))
    $texts = New-Object Windows.Controls.StackPanel
    $texts.Margin = Th 12 0 0 0; $texts.VerticalAlignment = 'Center'
    [void]$texts.Children.Add((New-Text $title 13.5 'Fg' 'SemiBold'))
    if ($desc) { [void]$texts.Children.Add((New-Text $desc 11.5 'FgDim')) }
    [void]$content.Children.Add($texts)

    $cb = New-Object Windows.Controls.CheckBox
    $cb.Content = $content
    $cb.VerticalContentAlignment = 'Center'
    $cb.IsChecked = $item.Def
    $cb.Add_Checked({ Update-Counts }); $cb.Add_Unchecked({ Update-Counts })
    [Windows.Controls.Grid]::SetColumn($cb, 1)
    [void]$g.Children.Add($cb)
    $row.Child = $g

    $item.CB = $cb; $item.Row = $row
    $item | Add-Member -NotePropertyName Icon -NotePropertyValue $icon -Force
    return $row
}

# ---------- 0: Başlangıç ----------
$os = Get-CimInstance Win32_OperatingSystem
$info = @(
    @('Ekran kartı', $(if ($hasNvidia) { 'NVIDIA algılandı' } else { 'NVIDIA yok' })),
    @('Cihaz', $(if ($isLaptop) { 'Laptop' } else { 'Masaüstü' })),
    @('Windows', "$($os.Caption -replace '^Microsoft ', '') ($($os.BuildNumber))")
)
foreach ($pair in $info) {
    $sp = New-Object Windows.Controls.StackPanel
    $sp.Margin = Th 16 0 16 0
    [void]$sp.Children.Add((New-Text $pair[0] 12 'FgDim'))
    [void]$sp.Children.Add((New-Text $pair[1] 15 'Fg' 'SemiBold'))
    [void]$ui.SysInfo.Children.Add($sp)
}

# ---------- 1: Uygulama kaldırma (sadece yüklü olanlar) ----------
$appxAll   = @(Get-AppxPackage -AllUsers)
if (-not $appxAll) { $appxAll = @(Get-AppxPackage) }   # -AllUsers yönetici ister; olmazsa mevcut kullanıcı
$installed = @($appxAll | Select-Object -ExpandProperty Name -Unique)
$shownApps = @($Apps | Where-Object { $installed -contains $_.Id })
foreach ($a in $shownApps) { $a | Add-Member -NotePropertyName Kind -NotePropertyValue 'appx' }

# Diğer Store uygulamaları: framework/sistem/kaldırılamaz olanlar ve oyun/kurulum için gerekenler hiç gösterilmez
$protectedAppx = @('Microsoft.WindowsStore', 'Microsoft.StorePurchaseApp', 'Microsoft.DesktopAppInstaller', 'Microsoft.Winget.Source',
                   'Microsoft.XboxIdentityProvider', 'Microsoft.Xbox.TCUI', 'Microsoft.SecHealthUI', 'Microsoft.LanguageExperiencePack*')
$redAppx = '^Microsoft\..*(Extension|Codec)|ApplicationCompatibility|Realtek|AMD|Radeon|NVIDIA|Intel|MSI|MICRO-STAR|Dolby|DTS|Synaptics|ASUS|Gigabyte|Razer|Logitech'
function Format-AppxName([string]$id) {
    # "9426MICRO-STARINTERNATION.MSICenter" -> "MSI Center", "Microsoft.HEVCVideoExtension" -> "HEVC Video Extension"
    $parts = $id -split '\.'
    $n = [regex]::Replace($parts[-1], '(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])', ' ').Trim()
    # Kısa ve okunur yayıncı öneki varsa başa ekle: "WinRAR.ShellExtension" -> "WinRAR Shell Extension"
    $pre = $parts[0]
    if ($parts.Count -gt 1 -and $pre -ne 'Microsoft' -and $pre -match '^[A-Za-z]{2,12}$' -and $n -notlike "$pre*") { $n = "$pre $n" }
    return $n
}
$otherStore = @($appxAll |
    Where-Object { -not $_.IsFramework -and $_.SignatureKind -ne 'System' -and -not $_.NonRemovable -and $Apps.Id -notcontains $_.Name } |
    Sort-Object Name -Unique)
$otherStore = @($otherStore | Where-Object { $name = $_.Name; -not ($protectedAppx | Where-Object { $name -like $_ }) })
$otherStore = @($otherStore | ForEach-Object {
    [pscustomobject]@{ Kind = 'appx'; Id = $_.Name; Name = (Format-AppxName $_.Name); Def = $false; CB = $null; Row = $null
                       Lvl = $(if ($_.Name -match $redAppx) { 'red' } else { 'yellow' }); Pkg = $_ }
})

# Klasik (Win32) programlar: Denetim Masası'ndaki kayıtlar; güncellemeler ve sistem bileşenleri hariç
$redWin32 = 'Visual C\+\+|\.NET|Runtime|Redistributable|Driver|Sürücü|NVIDIA|AMD|Radeon|Realtek|Intel|Chipset|DirectX|PhysX|Vulkan|SDK|' +
            'Ryzen|Dolby|MSI Center|Easy ?Anti-?Cheat|BattlEye|Vanguard|FACEIT|Windows'
$win32 = @(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
                            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
                            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' |
    Where-Object { $_.DisplayName -and ($_.UninstallString -or $_.QuietUninstallString) -and $_.SystemComponent -ne 1 -and
                   -not $_.ParentKeyName -and $_.ReleaseType -notmatch 'Update|Hotfix' -and
                   $_.DisplayName -notmatch '^Microsoft Edge|^Microsoft Update Health' } |
    Sort-Object DisplayName -Unique |
    ForEach-Object {
        [pscustomobject]@{ Kind = 'win32'; Id = $_.DisplayName; Name = $_.DisplayName; Def = $false; CB = $null; Row = $null
                           Uninstall = $_.UninstallString; Quiet = $_.QuietUninstallString; IconSpec = $_.DisplayIcon
                           Desc = $(if ($_.Publisher) { "$($_.Publisher)  ·  $($_.DisplayVersion)" } else { "$($_.DisplayVersion)" })
                           Lvl = $(if ($_.DisplayName -match $redWin32) { 'red' } else { 'yellow' }) }
    })

$RemoveItems = @($shownApps) + @($otherStore) + @($win32)
foreach ($a in $shownApps) {
    $pkg = $appxAll | Where-Object { $_.Name -eq $a.Id } | Select-Object -First 1
    [void]$ui.AppGrid.Children.Add((New-ListRow $a $a.Name $a.Id (Get-AppxIcon $pkg)))
}
foreach ($a in $otherStore) { [void]$ui.StoreGrid.Children.Add((New-ListRow $a $a.Name $a.Id (Get-AppxIcon $a.Pkg))) }
foreach ($a in $win32)      { [void]$ui.Win32Grid.Children.Add((New-ListRow $a $a.Name $a.Desc (Get-Win32Icon $a.IconSpec $a.Uninstall))) }
if ($shownApps.Count -eq 0) { $ui.AppEmpty.Visibility = 'Visible' }
Add-Legend $ui.Legend1

# ---------- 2: Ayarlar (3 sütunlu kategori kartları) ----------
$cats = [ordered]@{}
foreach ($t in $Tweaks) {
    if (-not $cats.Contains($t.Cat)) { $cats[$t.Cat] = New-Object System.Collections.ArrayList }
    [void]$cats[$t.Cat].Add($t)
}
$cols = @($ui.TCol0, $ui.TCol1, $ui.TCol2)
$colH = @(0, 0, 0)
$script:Cards = @()
foreach ($cat in $cats.Keys) {
    $items = $cats[$cat]
    $card = New-Card
    $card.Margin = Th 0 0 0 16
    $sp = New-Object Windows.Controls.StackPanel

    $head = New-Object Windows.Controls.DockPanel
    $head.Margin = Th 0 0 0 6
    $links = New-Object Windows.Controls.StackPanel
    $links.Orientation = 'Horizontal'; $links.VerticalAlignment = 'Center'
    [Windows.Controls.DockPanel]::SetDock($links, 'Right')
    foreach ($pair in @(@('Tümü', $true), @('Hiçbiri', $false))) {
        $lnk = New-Object Windows.Controls.Button
        $lnk.Style = $window.FindResource('Link')
        $lnk.Content = $pair[0]
        $lnk.Tag = @{ Items = $items; Value = $pair[1] }
        $lnk.Add_Click({ foreach ($t in $this.Tag.Items) { if ($t.Row.Visibility -eq 'Visible') { $t.CB.IsChecked = $this.Tag.Value } } })
        [void]$links.Children.Add($lnk)
    }
    [void]$head.Children.Add($links)
    [void]$head.Children.Add((New-Text $cat 17 'Fg' 'SemiBold'))
    [void]$sp.Children.Add($head)

    $h = 60
    foreach ($t in $items) {
        $r = New-OptionRow $t $t.Name $t.Desc
        $r.Margin = Th 0 8 0 4
        [void]$sp.Children.Add($r)
        $h += 34 + [math]::Ceiling(([string]$t.Desc).Length / 46) * 16
    }
    $card.Child = $sp
    # En kısa sütuna ekle (masonry)
    $i = 0
    for ($k = 1; $k -lt 3; $k++) { if ($colH[$k] -lt $colH[$i]) { $i = $k } }
    [void]$cols[$i].Children.Add($card)
    $colH[$i] += $h
    $script:Cards += [pscustomobject]@{ Card = $card; Items = $items }
}
Add-Legend $ui.Legend2

# "Diğer programları göster" kapalıyken sadece önerilen liste hesaba katılır
function Get-VisibleRemoveItems {
    if ($ui.ShowOther.IsChecked) { return $RemoveItems } else { return $shownApps }
}
$ui.ShowOther.Add_Checked({ $ui.OtherSection.Visibility = 'Visible'; Update-Counts })
$ui.ShowOther.Add_Unchecked({
    # Gizlenen listede seçili bir şey kalmasın
    $ui.OtherSection.Visibility = 'Collapsed'
    foreach ($a in @($otherStore) + @($win32)) { $a.CB.IsChecked = $false }
    Update-Counts
})
function Update-Counts {
    $vis = @(Get-VisibleRemoveItems)
    $ui.AppCount.Text   = "$(@($vis | Where-Object { $_.CB.IsChecked }).Count) / $($vis.Count) seçili"
    $ui.TweakCount.Text = "$(@($Tweaks | Where-Object { $_.CB.IsChecked }).Count) / $($Tweaks.Count) seçili"
}
$ui.AppSearch.Add_TextChanged({
    $q = $ui.AppSearch.Text.Trim()
    foreach ($a in $RemoveItems) {
        $a.Row.Visibility = if ((Test-Match $a.Name $q) -or (Test-Match $a.Id $q)) { 'Visible' } else { 'Collapsed' }
    }
})
$ui.TweakSearch.Add_TextChanged({
    $q = $ui.TweakSearch.Text.Trim()
    foreach ($c in $script:Cards) {
        $any = $false
        foreach ($t in $c.Items) {
            $hit = (Test-Match $t.Name $q) -or (Test-Match $t.Desc $q) -or (Test-Match $t.Cat $q)
            $t.Row.Visibility = if ($hit) { 'Visible' } else { 'Collapsed' }
            if ($hit) { $any = $true }
        }
        $c.Card.Visibility = if ($any) { 'Visible' } else { 'Collapsed' }
    }
})
$ui.AppRec.Add_Click({     foreach ($a in $RemoveItems) { $a.CB.IsChecked = $a.Def } })
$ui.AppClear.Add_Click({   foreach ($a in $RemoveItems) { $a.CB.IsChecked = $false } })

$ui.TweakRec.Add_Click({   foreach ($t in $Tweaks) { $t.CB.IsChecked = $t.Def } })
$ui.TweakClear.Add_Click({ foreach ($t in $Tweaks) { $t.CB.IsChecked = $false } })
Update-Counts

# ---------- 3: Kurulacak uygulamalar ----------
$InstallSites = @{
    'NVIDIA App' = 'https://www.nvidia.com/'; 'Discord' = 'https://discord.com/'; 'Opera' = 'https://www.opera.com/'
    'Google Chrome' = 'https://www.google.com/chrome/'; 'Steam' = 'https://store.steampowered.com/'; 'Logitech G HUB' = 'https://www.logitechg.com/'
}
foreach ($i in $Installs) {
    $icon = if ($InstallSites[$i.Name]) { Get-WebIcon $InstallSites[$i.Name] } else { $null }
    $i | Add-Member -NotePropertyName Icon -NotePropertyValue $icon -Force
    if ($icon) {
        # İnemezse özet ekranında boş kutu kalmasın
        $it = $i
        $icon.Add_DownloadFailed({ $it.Icon = $null }.GetNewClosure())
    }
    $card = New-Card
    $card.Width = 340; $card.Margin = Th 0 0 16 16
    $sp = New-Object Windows.Controls.StackPanel
    $top = New-Object Windows.Controls.DockPanel
    $badge = New-Object Windows.Controls.Border
    $badge.CornerRadius = New-Object Windows.CornerRadius(10)
    $badge.Padding = Th 10 2 10 3; $badge.VerticalAlignment = 'Center'; $badge.Visibility = 'Collapsed'
    $badgeText = New-Text '' 11.5 'Fg' 'SemiBold'
    $badge.Child = $badgeText
    [Windows.Controls.DockPanel]::SetDock($badge, 'Right')
    [void]$top.Children.Add($badge)
    $cb = New-Object Windows.Controls.CheckBox
    $cb.VerticalContentAlignment = 'Center'
    $head = New-Object Windows.Controls.StackPanel
    $head.Orientation = 'Horizontal'
    [void]$head.Children.Add((New-IconBox $icon $i.Name 32))
    $nm = New-Text $i.Name 15 'Fg' 'SemiBold'; $nm.Margin = Th 12 0 0 0; $nm.VerticalAlignment = 'Center'
    [void]$head.Children.Add($nm)
    $cb.Content = $head
    [void]$top.Children.Add($cb)
    [void]$sp.Children.Add($top)
    $d = New-Text $i.Desc 12 'FgDim'; $d.Margin = Th 26 8 0 0
    [void]$sp.Children.Add($d)
    $card.Child = $sp
    [void]$ui.InstWrap.Children.Add($card)
    $i.CB = $cb
    $i | Add-Member -NotePropertyName Badge -NotePropertyValue $badge
    $i | Add-Member -NotePropertyName BadgeText -NotePropertyValue $badgeText
}
function Set-Badge($i, [string]$text, [string]$hex) {
    $i.BadgeText.Text = $text
    $i.BadgeText.Foreground = New-Brush $hex
    $i.Badge.Background = New-Brush ($hex -replace '^#', '#30')
    $i.Badge.Visibility = 'Visible'
}
# Kurulu olanları tekrar algılar; kurulu olanın checkbox'ı pasif olur
function Update-InstallList {
    $names = Get-InstalledNames
    foreach ($i in $Installs) {
        if (Test-Installed $i $names) {
            $i.CB.IsChecked = $false; $i.CB.IsEnabled = $false; Set-Badge $i 'Zaten kurulu' '#3FA845'
        } elseif ($i.Name -eq 'NVIDIA App' -and -not $hasNvidia) {
            $i.CB.IsChecked = $false; $i.CB.IsEnabled = $false; Set-Badge $i 'NVIDIA kart yok' '#E5533F'
        } else {
            $i.CB.IsEnabled = $true; $i.Badge.Visibility = 'Collapsed'
        }
    }
}

# ---------- 4: Özet ----------
function Get-Selection {
    [pscustomobject]@{
        Apps     = @(Get-VisibleRemoveItems | Where-Object { $_.CB.IsChecked })
        Tweaks   = @($Tweaks | Where-Object { $_.CB.IsChecked })
        Installs = @($Installs | Where-Object { $_.CB.IsEnabled -and $_.CB.IsChecked })
    }
}
function New-SummaryCard([string]$title, $lines) {
    $card = New-Card
    $card.Margin = Th 0 0 0 16
    $sp = New-Object Windows.Controls.StackPanel
    [void]$sp.Children.Add((New-Text $title 17 'Fg' 'SemiBold'))
    if (-not $lines) { $e = New-Text 'Hiçbiri' 13 'FgDim'; $e.Margin = Th 0 8 0 0; [void]$sp.Children.Add($e) }
    foreach ($l in $lines) {
        if ($l -is [string]) {
            # Kategori başlığı
            $tb = New-Text $l 12 'Accent' 'SemiBold'; $tb.Margin = Th 0 12 0 2
            [void]$sp.Children.Add($tb)
        } else {
            $row = New-Object Windows.Controls.StackPanel
            $row.Orientation = 'Horizontal'; $row.Margin = Th 0 6 0 0
            [void]$row.Children.Add((New-Marker $l.Lvl))
            if ($l.PSObject.Properties['Icon']) {
                $ib = New-IconBox $l.Icon $l.Text 18; $ib.Margin = Th 0 0 8 0
                [void]$row.Children.Add($ib)
            }
            [void]$row.Children.Add((New-Text $l.Text 13))
            [void]$sp.Children.Add($row)
        }
    }
    $card.Child = $sp
    return $card
}
function Build-Summary {
    $p = $ui.SummaryPanel
    $p.Children.Clear()
    $s = Get-Selection
    if ($s.Apps.Count + $s.Tweaks.Count + $s.Installs.Count -eq 0) {
        $c = New-Card
        $c.Child = New-Text 'Hiçbir şey seçmedin. Geri dönüp seçim yapabilirsin.' 15 'FgDim'
        [void]$p.Children.Add($c)
        $ui.BtnNext.IsEnabled = $false
        return
    }
    $red = @(@($s.Apps) + @($s.Tweaks) | Where-Object { $_.Lvl -eq 'red' })
    if ($red.Count) {
        $w = New-Card
        $w.Margin = Th 0 0 0 16
        $w.BorderBrush = New-Brush '#F44336'; $w.Background = New-Brush '#22F44336'
        $w.Child = New-Text ("Dikkat gerektiren seçimler var: " + (($red | ForEach-Object { $_.Name }) -join ', ')) 13.5 'Fg' 'SemiBold'
        [void]$p.Children.Add($w)
    }
    $grid = New-Object Windows.Controls.Grid
    foreach ($k in 0..2) { [void]$grid.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition)) }

    $appLines = @($s.Apps | ForEach-Object { [pscustomobject]@{ Lvl = $_.Lvl; Text = $_.Name; Icon = $_.Icon } })
    $twLines = @()
    foreach ($cat in $cats.Keys) {
        $inCat = @($s.Tweaks | Where-Object { $_.Cat -eq $cat })
        if ($inCat.Count) {
            $twLines += $cat
            $twLines += @($inCat | ForEach-Object { [pscustomobject]@{ Lvl = $_.Lvl; Text = $_.Name } })
        }
    }
    $inLines = @($s.Installs | ForEach-Object { [pscustomobject]@{ Lvl = 'green'; Text = $_.Name; Icon = $_.Icon } })

    $cards = @(
        (New-SummaryCard "Kaldırılacak uygulamalar ($($s.Apps.Count))" $appLines),
        (New-SummaryCard "Uygulanacak ayarlar ($($s.Tweaks.Count))" $twLines),
        (New-SummaryCard "Kurulacak uygulamalar ($($s.Installs.Count))" $inLines)
    )
    for ($k = 0; $k -lt 3; $k++) {
        $cards[$k].VerticalAlignment = 'Top'
        $cards[$k].Margin = Th $(if ($k) { 8 } else { 0 }) 0 $(if ($k -lt 2) { 8 } else { 0 }) 16
        [Windows.Controls.Grid]::SetColumn($cards[$k], $k)
        [void]$grid.Children.Add($cards[$k])
    }
    [void]$p.Children.Add($grid)
}

# ---------- Sihirbaz gezinmesi ----------
$StepNames = @('Başlangıç', 'Uygulamalar', 'Ayarlar', 'Kurulum', 'Özet')
$script:dots = @()
for ($k = 0; $k -lt 5; $k++) {
    $d = New-Object Windows.Controls.Border
    $d.Height = 8; $d.Width = 8; $d.CornerRadius = New-Object Windows.CornerRadius(4); $d.Margin = Th 4 0 4 0
    [void]$ui.Dots.Children.Add($d)
    $script:dots += $d
}
$script:page = 0
$script:finished = $false
function Go-Page([int]$n) {
    $script:page = $n
    for ($k = 0; $k -le 5; $k++) { $ui["Page$k"].Visibility = if ($k -eq $n) { 'Visible' } else { 'Collapsed' } }
    $nav = if ($n -ge 1 -and $n -le 4) { 'Visible' } else { 'Hidden' }
    $ui.BtnBack.Visibility = $nav; $ui.BtnNext.Visibility = $nav
    $ui.BtnNext.IsEnabled = $true
    $ui.BtnNext.Content = if ($n -eq 4) { 'UYGULA' } else { 'İleri' }
    for ($k = 0; $k -lt 5; $k++) {
        $script:dots[$k].Width = if ($k -eq $n) { 24 } else { 8 }
        $script:dots[$k].SetResourceReference([Windows.Controls.Border]::BackgroundProperty, $(if ($k -le $n) { 'Accent' } else { 'CardBorder' }))
    }
    if ($n -le 4) { $ui.StepLabel.Text = "Adım $($n + 1) / 5  ·  $($StepNames[$n])" }
    $ui.Dots.Visibility = if ($n -le 4) { 'Visible' } else { 'Collapsed' }
    if ($n -eq 5) { $ui.StepLabel.Text = '' }
    if ($n -eq 3) { Update-InstallList }
    if ($n -eq 4) { Build-Summary }
}

# ---------- 5: Uygulama ----------
function Save-Log {
    if (-not $script:logFile) {
        $script:logFile = Join-Path ([Environment]::GetFolderPath('Desktop')) "debloat_log_$(Get-Date -Format 'yyyyMMdd_HHmm').txt"
    }
    $ui.RunLog.Text | Out-File -FilePath $script:logFile -Encoding utf8
}
function Set-Step([string]$text) {
    $script:stepNo++
    $ui.RunStep.Text = $text
    $ui.RunBar.Value = 100 * ($script:stepNo - 1) / $script:stepTotal
    Update-UI
}
function Start-Apply {
    $s = Get-Selection
    Go-Page 5
    $script:LogTarget = $ui.RunLog
    $ui.RunLog.Clear()
    $script:stepNo = 0
    $script:stepTotal = [math]::Max(1, $s.Apps.Count + $s.Tweaks.Count + $s.Installs.Count + 1)

    if ($s.Apps.Count) {
        Log '> Uygulamalar siliniyor...'
        $prov = Get-AppxProvisionedPackage -Online
        foreach ($a in $s.Apps) {
            Set-Step "Kaldırılıyor: $($a.Name)"
            if ($a.Kind -eq 'win32') {
                Uninstall-Win32 $a
                $left = (Get-InstalledNames) -contains $a.Id
            } else {
                Get-AppxPackage -AllUsers -Name $a.Id | Remove-AppxPackage -AllUsers
                $prov | Where-Object { $_.DisplayName -eq $a.Id } | Remove-AppxProvisionedPackage -Online -AllUsers | Out-Null
                $left = Get-AppxPackage -AllUsers -Name $a.Id
            }
            if ($left) { Log "   ! $($a.Name) silinemedi (ya da kaldırma penceresi iptal edildi)" } else { Log "   - $($a.Name)" }
        }
    }

    foreach ($t in $s.Tweaks) {
        Set-Step "[$($t.Cat)] $($t.Name)"
        Log "> [$($t.Cat)] $($t.Name)"
        try { & $t.Run } catch { Log "   ! hata: $($_.Exception.Message)" }
    }

    Set-Step 'Explorer yeniden başlatılıyor...'
    if ($s.Apps.Count + $s.Tweaks.Count) {
        Log '> Explorer yeniden başlatılıyor...'
        Stop-Process -Name explorer -Force
        Wait-UI 2500
        if (-not (Get-Process -Name explorer)) { Start-Process explorer.exe }
    }

    foreach ($i in $s.Installs) {
        Set-Step "Kuruluyor: $($i.Name)"
        Log "> [Kurulum] $($i.Name)"
        try {
            if ($i.Custom) { & $i.Custom } else { Install-Winget $i.WingetId }
        } catch { Log "   ! hata: $($_.Exception.Message)" }
        if (Test-Installed $i (Get-InstalledNames)) { Log "   + $($i.Name) kuruldu" }
        else { Log "   ! $($i.Name) kurulmuş görünmüyor, logu kontrol et" }
    }

    Save-Log
    Log "Bitti. Log: $script:logFile"
    $ui.RunBar.Value = 100
    $ui.RunTitle.Text = 'Bitti'
    $ui.RunStep.Text = "Log masaüstüne kaydedildi. Değişikliklerin tam oturması için bilgisayarı yeniden başlatman önerilir."
    $script:finished = $true
    $ui.BtnBack.Content = 'Kapat'; $ui.BtnBack.Visibility = 'Visible'
    $ui.BtnNext.Content = 'Yeniden başlat'; $ui.BtnNext.Visibility = 'Visible'
}

$ui.BtnStart.Add_Click({ Go-Page 1 })
$ui.BtnCheck.Add_Click({
    $ui.CheckLog.Visibility = 'Visible'
    $script:LogTarget = $ui.CheckLog
    $ui.BtnCheck.IsEnabled = $false
    Test-ScriptCode
    $ui.BtnCheck.IsEnabled = $true
})
$ui.BtnNext.Add_Click({
    if ($script:finished) { Restart-Computer -Force; return }
    if ($script:page -lt 4) { Go-Page ($script:page + 1) }
    elseif ($script:page -eq 4) { Start-Apply }
})
$ui.BtnBack.Add_Click({
    if ($script:finished) { $window.Close(); return }
    if ($script:page -gt 0) { Go-Page ($script:page - 1) }
})

# ---------- Pencere düğmeleri ----------
$ui.BtnMin.Add_Click({ $window.WindowState = 'Minimized' })
$ui.BtnMax.Add_Click({ $window.WindowState = if ($window.WindowState -eq 'Maximized') { 'Normal' } else { 'Maximized' } })
$ui.BtnClose.Add_Click({ $window.Close() })
$window.Add_StateChanged({
    $max = $window.WindowState -eq 'Maximized'
    # Ekranı kaplayınca pencere kenarları ekran dışına taşar, içeriden boşluk bırak
    $ui.Root.Padding = if ($max) { Th 7 7 7 7 } else { Th 0 0 0 0 }
    $ui.BtnMax.Content = [string][char]$(if ($max) { 0xE923 } else { 0xE922 })
})
$window.Add_SourceInitialized({
    # Windows 11 yuvarlak pencere köşeleri
    $h = (New-Object Windows.Interop.WindowInteropHelper($window)).Handle
    $v = 2
    [void][W11.Dwm]::DwmSetWindowAttribute($h, 33, [ref]$v, 4)
})

Go-Page 0
[void]$window.ShowDialog()
