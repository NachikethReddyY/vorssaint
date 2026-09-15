// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct MousePointerStrings {
    let section: String
    let customize: String
    let caption: String
    let acceleration: String
    let trackingSpeed: String
    let speed: String
    let revert: String
    let dpiNote: String
}

extension FeatureStrings {
    static func mousePointer(_ language: AppLanguage) -> MousePointerStrings {
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

extension MousePointerStrings {
    static let enUS = MousePointerStrings(
        section: "Pointer", customize: "Customize pointer",
        caption: "Adjusts pointer speed and acceleration for connected mice. Trackpads are not affected.",
        acceleration: "Pointer acceleration", trackingSpeed: "Tracking speed", speed: "Pointer speed",
        revert: "Revert to system defaults",
        dpiNote: "This changes macOS pointer scaling, not hardware DPI."
    )

    static let ptBR = MousePointerStrings(
        section: "Ponteiro", customize: "Personalizar ponteiro",
        caption: "Ajusta a velocidade e a aceleração do ponteiro nos mouses conectados. O trackpad não é afetado.",
        acceleration: "Aceleração do ponteiro", trackingSpeed: "Velocidade de rastreamento", speed: "Velocidade do ponteiro",
        revert: "Restaurar padrões do sistema",
        dpiNote: "Isso altera a escala do ponteiro no macOS, não o DPI físico."
    )

    static let tr = MousePointerStrings(
        section: "İmleç", customize: "İmleci özelleştir",
        caption: "Bağlı farelerin imleç hızını ve ivmesini ayarlar. İzleme dörtgeni etkilenmez.",
        acceleration: "İmleç ivmesi", trackingSpeed: "İzleme hızı", speed: "İmleç hızı",
        revert: "Sistem varsayılanlarına dön",
        dpiNote: "Bu, donanım DPI değerini değil macOS imleç ölçeklemesini değiştirir."
    )

    static let ru = MousePointerStrings(
        section: "Указатель", customize: "Настроить указатель",
        caption: "Настраивает скорость и ускорение указателя для подключённых мышей. Трекпад не затрагивается.",
        acceleration: "Ускорение указателя", trackingSpeed: "Скорость отслеживания", speed: "Скорость указателя",
        revert: "Вернуть системные настройки",
        dpiNote: "Меняется масштабирование указателя macOS, а не аппаратный DPI."
    )

    static let es = MousePointerStrings(
        section: "Puntero", customize: "Personalizar puntero",
        caption: "Ajusta la velocidad y la aceleración del puntero de los ratones conectados. El trackpad no se ve afectado.",
        acceleration: "Aceleración del puntero", trackingSpeed: "Velocidad de seguimiento", speed: "Velocidad del puntero",
        revert: "Restablecer valores del sistema",
        dpiNote: "Esto cambia la escala del puntero de macOS, no los DPI del hardware."
    )

    static let de = MousePointerStrings(
        section: "Zeiger", customize: "Zeiger anpassen",
        caption: "Passt Zeigergeschwindigkeit und -beschleunigung für verbundene Mäuse an. Trackpads bleiben unverändert.",
        acceleration: "Zeigerbeschleunigung", trackingSpeed: "Abtastgeschwindigkeit", speed: "Zeigergeschwindigkeit",
        revert: "Auf Systemstandard zurücksetzen",
        dpiNote: "Dies ändert die macOS-Zeigerskalierung, nicht die Hardware-DPI."
    )

    static let fr = MousePointerStrings(
        section: "Pointeur", customize: "Personnaliser le pointeur",
        caption: "Règle la vitesse et l’accélération du pointeur des souris connectées. Le trackpad n’est pas affecté.",
        acceleration: "Accélération du pointeur", trackingSpeed: "Vitesse de suivi", speed: "Vitesse du pointeur",
        revert: "Rétablir les réglages système",
        dpiNote: "Cela modifie la mise à l’échelle du pointeur macOS, pas les PPP matériels."
    )

    static let it = MousePointerStrings(
        section: "Puntatore", customize: "Personalizza puntatore",
        caption: "Regola velocità e accelerazione del puntatore per i mouse collegati. Il trackpad non viene modificato.",
        acceleration: "Accelerazione del puntatore", trackingSpeed: "Velocità di tracciamento", speed: "Velocità del puntatore",
        revert: "Ripristina impostazioni di sistema",
        dpiNote: "Modifica il ridimensionamento del puntatore di macOS, non i DPI hardware."
    )

    static let ja = MousePointerStrings(
        section: "ポインタ", customize: "ポインタをカスタマイズ",
        caption: "接続したマウスのポインタ速度と加速度を調整します。トラックパッドには影響しません。",
        acceleration: "ポインタの加速度", trackingSpeed: "軌跡の速さ", speed: "ポインタの速度",
        revert: "システムのデフォルトに戻す",
        dpiNote: "変更するのは macOS のポインタ倍率で、ハードウェア DPI ではありません。"
    )

    static let ko = MousePointerStrings(
        section: "포인터", customize: "포인터 사용자화",
        caption: "연결된 마우스의 포인터 속도와 가속을 조절합니다. 트랙패드에는 영향을 주지 않습니다.",
        acceleration: "포인터 가속", trackingSpeed: "이동 속도", speed: "포인터 속도",
        revert: "시스템 기본값으로 복원",
        dpiNote: "하드웨어 DPI가 아니라 macOS 포인터 배율을 변경합니다."
    )

    static let zhHans = MousePointerStrings(
        section: "指针", customize: "自定义指针",
        caption: "调整已连接鼠标的指针速度和加速度，不影响触控板。",
        acceleration: "指针加速度", trackingSpeed: "跟踪速度", speed: "指针速度",
        revert: "恢复系统默认设置",
        dpiNote: "这会更改 macOS 指针缩放，而不是硬件 DPI。"
    )

    static let zhTW = MousePointerStrings(
        section: "指標", customize: "自訂指標",
        caption: "調整已連接滑鼠的指標速度與加速度，不影響觸控式軌跡板。",
        acceleration: "指標加速度", trackingSpeed: "軌跡速度", speed: "指標速度",
        revert: "回復系統預設值",
        dpiNote: "這會更改 macOS 指標縮放，而不是硬體 DPI。"
    )

    static let zhHK = MousePointerStrings(
        section: "指標", customize: "自訂指標",
        caption: "調整已連接滑鼠的指標速度與加速度，不影響觸控板。",
        acceleration: "指標加速度", trackingSpeed: "移動速度", speed: "指標速度",
        revert: "回復系統預設值",
        dpiNote: "這會更改 macOS 指標縮放，而不是硬件 DPI。"
    )
}
