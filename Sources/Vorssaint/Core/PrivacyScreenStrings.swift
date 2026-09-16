// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct PrivacyScreenFeatureStrings {
    let title: String
    let hubDescription: String
    let enabled: String
    let caption: String
    let messageLabel: String
    let messagePlaceholder: String
    let messageCaption: String
    let sharingBoundary: String
}

extension FeatureStrings {
    static func privacyScreen(_ language: AppLanguage) -> PrivacyScreenFeatureStrings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .ptBR
        case .tr: return .tr
        case .ru: return .ru
        case .es: return .es
        case .de: return .de
        case .fr: return .fr
        case .it: return .it
        case .ja: return .ja
        case .ko: return .ko
        case .zhHans: return .zhHans
        case .zhTW: return .zhTW
        case .zhHK: return .zhHK
        }
    }
}

extension PrivacyScreenFeatureStrings {
    static let enUS = PrivacyScreenFeatureStrings(
        title: "Privacy Share",
        hubDescription: "Share a safe desktop mirror that can hide without blocking your work",
        enabled: "Enable Privacy Share shortcut",
        caption: "Use the shortcut to open Privacy Share and switch its live desktop mirror between normal and heavily distorted.",
        messageLabel: "Message",
        messagePlaceholder: "Screen hidden",
        messageCaption: "Shown in the center of the Privacy Share window while its contents are distorted.",
        sharingBoundary: "In your meeting app, share the Privacy Share window, not the original display. Your desktop remains visible and usable only to you."
    )
    static let ptBR = PrivacyScreenFeatureStrings(
        title: "Tela de privacidade", hubDescription: "Oculta todas as telas atrás de uma mensagem segura durante o compartilhamento",
        enabled: "Ativar atalho da tela de privacidade", caption: "Substitui cada tela por uma camada opaca; os pixels cobertos não podem ser recuperados removendo desfoque.",
        messageLabel: "Mensagem", messagePlaceholder: "Tela oculta",
        messageCaption: "Aparece no centro de cada tela enquanto a proteção está ativa.", sharingBoundary: "Protege o compartilhamento da tela inteira. Compartilhar uma janela ou aba pode ignorar sobreposições de outros apps."
    )
    static let tr = PrivacyScreenFeatureStrings(
        title: "Gizlilik ekranı", hubDescription: "Paylaşım sırasında tüm ekranları güvenli bir mesajın arkasında gizler",
        enabled: "Gizlilik ekranı kestirmesini etkinleştir", caption: "Her ekranı opak bir yüzeyle değiştirir; kapatılan pikseller bulanıklık giderilerek kurtarılamaz.",
        messageLabel: "Mesaj", messagePlaceholder: "Ekran gizli",
        messageCaption: "Gizlilik ekranı etkinken her ekranın ortasında gösterilir.", sharingBoundary: "Tam ekran paylaşımını korur. Pencere ve tarayıcı sekmesi paylaşımı diğer uygulamaların katmanlarını atlayabilir."
    )
    static let ru = PrivacyScreenFeatureStrings(
        title: "Экран конфиденциальности", hubDescription: "Скрывает все дисплеи за безопасным сообщением во время демонстрации",
        enabled: "Включить сочетание экрана конфиденциальности", caption: "Заменяет каждый дисплей непрозрачным экраном, поэтому скрытые пиксели нельзя восстановить удалением размытия.",
        messageLabel: "Сообщение", messagePlaceholder: "Экран скрыт",
        messageCaption: "Показывается в центре каждого дисплея, пока защита активна.", sharingBoundary: "Защищает демонстрацию всего дисплея. Демонстрация окна или вкладки может обходить наложения других приложений."
    )
    static let es = PrivacyScreenFeatureStrings(
        title: "Pantalla de privacidad", hubDescription: "Oculta todas las pantallas tras un mensaje seguro al compartir",
        enabled: "Activar atajo de pantalla de privacidad", caption: "Sustituye cada pantalla por una capa opaca; los píxeles cubiertos no pueden recuperarse quitando el desenfoque.",
        messageLabel: "Mensaje", messagePlaceholder: "Pantalla oculta",
        messageCaption: "Aparece en el centro de cada pantalla mientras la protección está activa.", sharingBoundary: "Protege al compartir la pantalla completa. Compartir una ventana o pestaña puede omitir capas de otras apps."
    )
    static let de = PrivacyScreenFeatureStrings(
        title: "Privatsphäre-Bildschirm", hubDescription: "Verdeckt beim Teilen alle Displays mit einer sicheren Nachricht",
        enabled: "Kurzbefehl für Privatsphäre-Bildschirm aktivieren", caption: "Ersetzt jedes Display durch eine undurchsichtige Fläche; verdeckte Pixel lassen sich nicht durch Entschärfen wiederherstellen.",
        messageLabel: "Nachricht", messagePlaceholder: "Bildschirm verborgen",
        messageCaption: "Wird bei aktivem Schutz mittig auf jedem Display angezeigt.", sharingBoundary: "Schützt das Teilen eines ganzen Displays. Fenster- und Tab-Freigaben können Einblendungen anderer Apps umgehen."
    )
    static let fr = PrivacyScreenFeatureStrings(
        title: "Écran de confidentialité", hubDescription: "Masque tous les écrans derrière un message sûr pendant le partage",
        enabled: "Activer le raccourci de confidentialité", caption: "Remplace chaque écran par une surface opaque\u{00A0}; aucun défloutage ne peut récupérer les pixels couverts.",
        messageLabel: "Message", messagePlaceholder: "Écran masqué",
        messageCaption: "S’affiche au centre de chaque écran tant que la protection est active.", sharingBoundary: "Protège le partage de l’écran entier. Le partage d’une fenêtre ou d’un onglet peut ignorer les surfaces des autres apps."
    )
    static let it = PrivacyScreenFeatureStrings(
        title: "Schermata privacy", hubDescription: "Nasconde tutti gli schermi dietro un messaggio sicuro durante la condivisione",
        enabled: "Attiva scorciatoia schermata privacy", caption: "Sostituisce ogni schermo con una superficie opaca; i pixel coperti non possono essere recuperati rimuovendo la sfocatura.",
        messageLabel: "Messaggio", messagePlaceholder: "Schermo nascosto",
        messageCaption: "Appare al centro di ogni schermo mentre la protezione è attiva.", sharingBoundary: "Protegge la condivisione dell’intero schermo. La condivisione di finestre o schede può ignorare le superfici di altre app."
    )
    static let ja = PrivacyScreenFeatureStrings(
        title: "プライバシー画面", hubDescription: "共有中、すべてのディスプレイを安全なメッセージで隠します",
        enabled: "プライバシー画面のショートカットを有効にする", caption: "各ディスプレイを不透明な画面に置き換えるため、ぼかし解除で隠れたピクセルを復元できません。",
        messageLabel: "メッセージ", messagePlaceholder: "画面を隠しています",
        messageCaption: "プライバシー画面の使用中、各ディスプレイの中央に表示します。", sharingBoundary: "ディスプレイ全体の共有を保護します。ウインドウやブラウザタブの共有では、他のアプリのオーバーレイが除外される場合があります。"
    )
    static let ko = PrivacyScreenFeatureStrings(
        title: "개인정보 보호 화면", hubDescription: "공유 중 모든 화면을 안전한 메시지로 가립니다",
        enabled: "개인정보 보호 화면 단축키 활성화", caption: "각 화면을 불투명한 화면으로 대체하여 흐림 제거로 가려진 픽셀을 복원할 수 없습니다.",
        messageLabel: "메시지", messagePlaceholder: "화면을 가렸습니다",
        messageCaption: "보호 화면이 활성화된 동안 각 디스플레이 중앙에 표시됩니다.", sharingBoundary: "전체 디스플레이 공유를 보호합니다. 창이나 브라우저 탭 공유는 다른 앱의 오버레이를 제외할 수 있습니다."
    )
    static let zhHans = PrivacyScreenFeatureStrings(
        title: "隐私屏幕", hubDescription: "共享时用安全消息遮住所有显示器",
        enabled: "启用隐私屏幕快捷键", caption: "用不透明画面替换每个显示器，无法通过去模糊恢复被遮住的像素。",
        messageLabel: "消息", messagePlaceholder: "屏幕已隐藏",
        messageCaption: "隐私屏幕启用时显示在每个显示器中央。", sharingBoundary: "可保护整个显示器共享。共享单个窗口或浏览器标签页可能会绕过其他 App 的遮罩。"
    )
    static let zhTW = PrivacyScreenFeatureStrings(
        title: "隱私畫面", hubDescription: "分享時以安全訊息遮住所有顯示器",
        enabled: "啟用隱私畫面快捷鍵", caption: "以不透明畫面取代每個顯示器，無法透過去除模糊還原被遮住的像素。",
        messageLabel: "訊息", messagePlaceholder: "畫面已隱藏",
        messageCaption: "隱私畫面啟用時顯示於每個顯示器中央。", sharingBoundary: "可保護整個顯示器分享。分享單一視窗或瀏覽器分頁可能會略過其他 App 的遮罩。"
    )
    static let zhHK = PrivacyScreenFeatureStrings(
        title: "私隱畫面", hubDescription: "分享時以安全訊息遮住所有顯示器",
        enabled: "啟用私隱畫面快捷鍵", caption: "以不透明畫面取代每個顯示器，無法透過移除模糊還原被遮住的像素。",
        messageLabel: "訊息", messagePlaceholder: "畫面已隱藏",
        messageCaption: "私隱畫面啟用時顯示於每個顯示器中央。", sharingBoundary: "可保護整個顯示器分享。分享單一視窗或瀏覽器分頁可能會略過其他 App 的遮罩。"
    )
}
