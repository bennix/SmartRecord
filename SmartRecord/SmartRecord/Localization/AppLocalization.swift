import Foundation

nonisolated enum AppLanguage: String, CaseIterable, Identifiable {
    case zhHans
    case zhHant
    case en
    case ja
    case ko
    case pt
    case es
    case it
    case fr
    case sv
    case fi

    var id: String { rawValue }

    var nativeName: String {
        switch self {
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        case .en: return "English"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .pt: return "Português"
        case .es: return "Español"
        case .it: return "Italiano"
        case .fr: return "Français"
        case .sv: return "Svenska"
        case .fi: return "Suomi"
        }
    }
}

nonisolated enum AppText: String, CaseIterable {
    case appSubtitle
    case language
    case audioMode
    case recordingFrameRate
    case generateVTTSubtitles
    case capturePipeline
    case screenAndSystemAudio
    case screenRecordingPermissionRequired
    case openSettings
    case mouseClickSmartFocus
    case clickAreaAutoZoom
    case audioMix
    case whisperSubtitles
    case mediumModel
    case connectingDownloadSource
    case downloading
    case downloadMedium
    case openModelFolder
    case openModelDownloadPage
    case recordingProjects
    case projectsDescription
    case projectsMetric
    case eventsMetric
    case noRecordings
    case noRecordingsDescription
    case starting
    case stopRecording
    case startRecording
    case startedAt
    case noSubtitles
    case waitingMP4
    case waitingVTT
    case skipVTT
    case noClickEvents
    case play
    case video
    case subtitles
    case delete
    case playRecording
    case regenerateVideo
    case regenerateSubtitles
    case showInFinder
    case skipped
    case recording
    case saved
    case renderingVideo
    case transcribing
    case completed
    case videoFailed
    case subtitleFailed
    case missingMicrophoneAudio
    case missingSystemAudio
    case missingSubtitleAudio
    case whisperCommandNotInstalled
    case whisperMediumModelMissing
    case audioConverterNotInstalled
    case audioBoth
    case audioMicrophoneOnly
    case audioSystemOnly
    case audioNone
    case preparingRecording
    case preparingRecordingLong
    case startFailed
    case savingRawAssets
    case recorderNotStarted
    case mouseEventCacheLost
    case saveFailed
    case rawAssetsSaved
    case rawAssetsSavedWithWarnings
    case projectSaveFailed
    case fileGeneratedProjectSaveFailed
    case checkingMediumModel
    case mediumModelReady
    case mediumModelNotInstalled
    case downloadingMediumModelLarge
    case downloadingMediumModelProgress
    case downloadingMediumModel
    case mediumModelDownloaded
    case subtitleModelReady
    case mediumModelDownloadFailed
    case subtitleModelUnavailable
    case startFailedWithDetail
    case screenPermissionStatus
    case screenPermissionDenied
    case noRecordableDisplay
    case recordingTooShort
    case screenPermissionRecovery
    case missingAssetDirectory
    case unknownWriterError
    case writerFailed
    case missingScreenVideo
    case noVideoTrack
    case exportUnavailable
    case exportFailed
    case unknownError
    case missingWhisperCommandError
    case missingSubtitleAudioError
    case missingMediumModelError
    case missingAudioConverterError
    case whisperFailed
    case unknownWhisperError
    case whisperDidNotGenerateVTT
    case mediumModelIncomplete
    case mediumModelServerFailed
}

nonisolated struct AppStrings {
    let language: AppLanguage

    init(_ language: AppLanguage) {
        self.language = language
    }

    static var current: AppStrings {
        let rawValue = UserDefaults.standard.string(forKey: AppLanguageStore.userDefaultsKey)
        return AppStrings(AppLanguage(rawValue: rawValue ?? "") ?? .zhHans)
    }

    func callAsFunction(_ key: AppText) -> String {
        Self.table[key]?[language] ?? Self.table[key]?[.zhHans] ?? key.rawValue
    }

    func audioModeLabel(_ mode: AudioCaptureMode) -> String {
        switch mode {
        case .both: return self(.audioBoth)
        case .microphoneOnly: return self(.audioMicrophoneOnly)
        case .systemOnly: return self(.audioSystemOnly)
        case .none: return self(.audioNone)
        }
    }

    func frameRateLabel(_ frameRate: RecordingFrameRate) -> String {
        "\(frameRate.rawValue) fps"
    }

    func startedAt(_ value: String) -> String {
        String(format: self(.startedAt), value)
    }

    func projectSaveFailed(_ detail: String) -> String {
        String(format: self(.projectSaveFailed), detail)
    }

    func startFailedWithDetail(_ detail: String) -> String {
        String(format: self(.startFailedWithDetail), detail)
    }

    func writerFailed(_ detail: String) -> String {
        String(format: self(.writerFailed), detail)
    }

    func exportFailed(_ detail: String) -> String {
        String(format: self(.exportFailed), detail)
    }

    func whisperFailed(code: Int32, message: String) -> String {
        String(format: self(.whisperFailed), Int(code), message)
    }

    func mediumModelServerFailed(_ code: Int) -> String {
        String(format: self(.mediumModelServerFailed), code)
    }

    func downloadingMediumModelProgress(_ percent: Int) -> String {
        String(format: self(.downloadingMediumModelProgress), percent)
    }

    private static func values(
        _ zhHans: String,
        _ zhHant: String,
        _ en: String,
        _ ja: String,
        _ ko: String,
        _ pt: String,
        _ es: String,
        _ it: String,
        _ fr: String,
        _ sv: String,
        _ fi: String
    ) -> [AppLanguage: String] {
        [
            .zhHans: zhHans,
            .zhHant: zhHant,
            .en: en,
            .ja: ja,
            .ko: ko,
            .pt: pt,
            .es: es,
            .it: it,
            .fr: fr,
            .sv: sv,
            .fi: fi
        ]
    }

    private static let table: [AppText: [AppLanguage: String]] = [
        .appSubtitle: values("屏幕、系统声音、麦克风、SmartFocus、VTT", "螢幕、系統聲音、麥克風、SmartFocus、VTT", "Screen, system audio, microphone, SmartFocus, VTT", "画面、システム音声、マイク、SmartFocus、VTT", "화면, 시스템 오디오, 마이크, SmartFocus, VTT", "Tela, audio do sistema, microfone, SmartFocus, VTT", "Pantalla, audio del sistema, micrófono, SmartFocus, VTT", "Schermo, audio di sistema, microfono, SmartFocus, VTT", "Ecran, audio systeme, micro, SmartFocus, VTT", "Skarm, systemljud, mikrofon, SmartFocus, VTT", "Naytto, jarjestelmaaani, mikrofoni, SmartFocus, VTT"),
        .language: values("语言", "語言", "Language", "言語", "언어", "Idioma", "Idioma", "Lingua", "Langue", "Sprak", "Kieli"),
        .audioMode: values("录音模式", "錄音模式", "Audio mode", "音声モード", "오디오 모드", "Modo de audio", "Modo de audio", "Modalita audio", "Mode audio", "Ljudlage", "Aanentila"),
        .recordingFrameRate: values("录制帧率", "錄製影格率", "Recording frame rate", "録画フレームレート", "녹화 프레임 속도", "Taxa de quadros", "Velocidad de fotogramas", "Frequenza fotogrammi", "Frequence d'image", "Bildfrekvens", "Kuvataajuus"),
        .generateVTTSubtitles: values("生成 VTT 字幕", "產生 VTT 字幕", "Generate VTT subtitles", "VTT字幕を生成", "VTT 자막 생성", "Gerar legendas VTT", "Generar subtitulos VTT", "Genera sottotitoli VTT", "Generer les sous-titres VTT", "Skapa VTT-undertexter", "Luo VTT-tekstitys"),
        .capturePipeline: values("录制链路", "錄製鏈路", "Capture pipeline", "キャプチャ経路", "캡처 파이프라인", "Pipeline de captura", "Canal de captura", "Pipeline di acquisizione", "Pipeline de capture", "Inspelningskedja", "Tallennusketju"),
        .screenAndSystemAudio: values("屏幕与系统声音", "螢幕與系統聲音", "Screen and system audio", "画面とシステム音声", "화면 및 시스템 오디오", "Tela e audio do sistema", "Pantalla y audio del sistema", "Schermo e audio di sistema", "Ecran et audio systeme", "Skarm och systemljud", "Naytto ja jarjestelmaaani"),
        .screenRecordingPermissionRequired: values("需要屏幕录制权限", "需要螢幕錄製權限", "Screen recording permission required", "画面収録権限が必要です", "화면 녹화 권한 필요", "Permissao de gravacao de tela necessaria", "Se requiere permiso de grabacion de pantalla", "Serve il permesso di registrazione schermo", "Autorisation d'enregistrement d'ecran requise", "Skarm inspelningsbehorighet kravs", "Nayton tallennusoikeus vaaditaan"),
        .openSettings: values("打开设置", "開啟設定", "Open Settings", "設定を開く", "설정 열기", "Abrir Ajustes", "Abrir ajustes", "Apri impostazioni", "Ouvrir les reglages", "Oppna installningar", "Avaa asetukset"),
        .mouseClickSmartFocus: values("鼠标点击 SmartFocus", "滑鼠點擊 SmartFocus", "Mouse-click SmartFocus", "マウスクリック SmartFocus", "마우스 클릭 SmartFocus", "SmartFocus por clique", "SmartFocus con clic", "SmartFocus al clic", "SmartFocus au clic", "SmartFocus vid klick", "SmartFocus klikkauksesta"),
        .clickAreaAutoZoom: values("点击区域自动放大回弹", "點擊區域自動放大回彈", "Click area auto-zooms and returns", "クリック領域を自動ズームして戻す", "클릭 영역 자동 확대 후 복귀", "A area clicada amplia e volta", "El area clicada se acerca y vuelve", "L'area cliccata si ingrandisce e torna", "La zone cliquee zoome puis revient", "Klickomradet zoomas och atergar", "Klikattu alue zoomaa ja palaa"),
        .audioMix: values("音频混合", "音訊混合", "Audio mix", "音声ミックス", "오디오 믹스", "Mixagem de audio", "Mezcla de audio", "Mix audio", "Mixage audio", "Ljudmix", "Aanen miksaus"),
        .whisperSubtitles: values("Whisper 字幕", "Whisper 字幕", "Whisper subtitles", "Whisper字幕", "Whisper 자막", "Legendas Whisper", "Subtitulos Whisper", "Sottotitoli Whisper", "Sous-titres Whisper", "Whisper-undertexter", "Whisper-tekstitys"),
        .mediumModel: values("medium 模型", "medium 模型", "medium model", "mediumモデル", "medium 모델", "Modelo medium", "Modelo medium", "Modello medium", "Modele medium", "medium-modell", "medium-malli"),
        .connectingDownloadSource: values("正在连接下载源", "正在連接下載來源", "Connecting to download source", "ダウンロード元に接続中", "다운로드 소스 연결 중", "Conectando a fonte de download", "Conectando con la fuente de descarga", "Connessione alla fonte di download", "Connexion a la source de telechargement", "Ansluter till hamtningskallan", "Yhdistetaan latauslahteeseen"),
        .downloading: values("下载中", "下載中", "Downloading", "ダウンロード中", "다운로드 중", "Baixando", "Descargando", "Download in corso", "Telechargement", "Hamtar", "Ladataan"),
        .downloadMedium: values("下载 medium", "下載 medium", "Download medium", "mediumをダウンロード", "medium 다운로드", "Baixar medium", "Descargar medium", "Scarica medium", "Telecharger medium", "Hamta medium", "Lataa medium"),
        .openModelFolder: values("打开模型目录", "開啟模型目錄", "Open model folder", "モデルフォルダを開く", "모델 폴더 열기", "Abrir pasta do modelo", "Abrir carpeta del modelo", "Apri cartella modello", "Ouvrir le dossier du modele", "Oppna modellmapp", "Avaa mallikansio"),
        .openModelDownloadPage: values("打开模型下载页", "開啟模型下載頁", "Open model download page", "モデルのダウンロードページを開く", "모델 다운로드 페이지 열기", "Abrir pagina de download do modelo", "Abrir pagina de descarga del modelo", "Apri pagina download modello", "Ouvrir la page de telechargement du modele", "Oppna modellens hamtningssida", "Avaa mallin lataussivu"),
        .recordingProjects: values("录制项目", "錄製項目", "Recording projects", "録画プロジェクト", "녹화 프로젝트", "Projetos de gravacao", "Proyectos de grabacion", "Progetti registrati", "Projets d'enregistrement", "Inspelningsprojekt", "Tallennusprojektit"),
        .projectsDescription: values("点击任意项目播放 final.mp4；若未生成，则打开原始 screen.mov。", "點擊任一項目播放 final.mp4；若未產生，則開啟原始 screen.mov。", "Click any project to play final.mp4; if it is missing, the raw screen.mov opens.", "任意のプロジェクトをクリックしてfinal.mp4を再生します。未生成なら元のscreen.movを開きます。", "프로젝트를 클릭하면 final.mp4를 재생하고, 없으면 원본 screen.mov를 엽니다.", "Clique em um projeto para reproduzir final.mp4; se faltar, abre o screen.mov original.", "Haz clic en un proyecto para reproducir final.mp4; si falta, se abre screen.mov original.", "Fai clic su un progetto per riprodurre final.mp4; se manca, apre screen.mov originale.", "Cliquez sur un projet pour lire final.mp4 ; s'il manque, screen.mov brut s'ouvre.", "Klicka pa ett projekt for att spela final.mp4; saknas den oppnas screen.mov.", "Avaa final.mp4 napsauttamalla projektia; jos se puuttuu, avataan raaka screen.mov."),
        .projectsMetric: values("项目", "項目", "Projects", "プロジェクト", "프로젝트", "Projetos", "Proyectos", "Progetti", "Projets", "Projekt", "Projektit"),
        .eventsMetric: values("事件", "事件", "Events", "イベント", "이벤트", "Eventos", "Eventos", "Eventi", "Evenements", "Handelser", "Tapahtumat"),
        .noRecordings: values("还没有录制", "尚未錄製", "No recordings yet", "録画はまだありません", "아직 녹화 없음", "Ainda sem gravacoes", "Aun no hay grabaciones", "Nessuna registrazione", "Aucun enregistrement", "Inga inspelningar an", "Ei tallenteita viela"),
        .noRecordingsDescription: values("开始录制后，这里会显示原始素材、SmartFocus MP4 和 VTT 字幕状态。", "開始錄製後，這裡會顯示原始素材、SmartFocus MP4 與 VTT 字幕狀態。", "After recording starts, raw assets, SmartFocus MP4, and VTT subtitle status appear here.", "録画を開始すると、元素材、SmartFocus MP4、VTT字幕の状態がここに表示されます。", "녹화를 시작하면 원본, SmartFocus MP4, VTT 자막 상태가 여기에 표시됩니다.", "Apos gravar, os arquivos brutos, o MP4 SmartFocus e o status VTT aparecem aqui.", "Al grabar, aqui veras recursos originales, MP4 SmartFocus y estado VTT.", "Dopo la registrazione vedrai asset grezzi, MP4 SmartFocus e stato VTT.", "Apres l'enregistrement, les sources, le MP4 SmartFocus et l'etat VTT s'affichent ici.", "Efter inspelning visas originalfiler, SmartFocus MP4 och VTT-status har.", "Tallennuksen jalkeen raakasisalto, SmartFocus MP4 ja VTT-tila nakyvat tassa."),
        .starting: values("正在启动", "正在啟動", "Starting", "開始中", "시작 중", "Iniciando", "Iniciando", "Avvio", "Demarrage", "Startar", "Kaynnistyy"),
        .stopRecording: values("停止录制", "停止錄製", "Stop recording", "録画を停止", "녹화 중지", "Parar gravacao", "Detener grabacion", "Ferma registrazione", "Arreter l'enregistrement", "Stoppa inspelning", "Pysayta tallennus"),
        .startRecording: values("开始录制", "開始錄製", "Start recording", "録画を開始", "녹화 시작", "Iniciar gravacao", "Iniciar grabacion", "Avvia registrazione", "Demarrer l'enregistrement", "Starta inspelning", "Aloita tallennus"),
        .startedAt: values("开始于 %@", "開始於 %@", "Started at %@", "%@ に開始", "%@ 시작", "Iniciou as %@", "Inicio a las %@", "Avviato alle %@", "Demarre a %@", "Startade %@", "Alkoi %@"),
        .noSubtitles: values("无字幕", "無字幕", "No subtitles", "字幕なし", "자막 없음", "Sem legendas", "Sin subtitulos", "Nessun sottotitolo", "Sans sous-titres", "Inga undertexter", "Ei tekstitysta"),
        .waitingMP4: values("等待 MP4", "等待 MP4", "Waiting for MP4", "MP4待機中", "MP4 대기 중", "Aguardando MP4", "Esperando MP4", "In attesa di MP4", "En attente du MP4", "Vantar pa MP4", "Odottaa MP4:aa"),
        .waitingVTT: values("等待 VTT", "等待 VTT", "Waiting for VTT", "VTT待機中", "VTT 대기 중", "Aguardando VTT", "Esperando VTT", "In attesa di VTT", "En attente du VTT", "Vantar pa VTT", "Odottaa VTT:tä"),
        .skipVTT: values("跳过 VTT", "略過 VTT", "Skip VTT", "VTTをスキップ", "VTT 건너뜀", "Ignorar VTT", "Omitir VTT", "Salta VTT", "Ignorer VTT", "Hoppa over VTT", "Ohita VTT"),
        .noClickEvents: values("无点击事件", "無點擊事件", "No click events", "クリックイベントなし", "클릭 이벤트 없음", "Sem eventos de clique", "Sin eventos de clic", "Nessun clic", "Aucun clic", "Inga klickhandelser", "Ei klikkaustapahtumia"),
        .play: values("播放", "播放", "Play", "再生", "재생", "Reproduzir", "Reproducir", "Riproduci", "Lire", "Spela", "Toista"),
        .video: values("视频", "影片", "Video", "動画", "비디오", "Video", "Video", "Video", "Video", "Video", "Video"),
        .subtitles: values("字幕", "字幕", "Subtitles", "字幕", "자막", "Legendas", "Subtitulos", "Sottotitoli", "Sous-titres", "Undertexter", "Tekstitys"),
        .delete: values("删除", "刪除", "Delete", "削除", "삭제", "Excluir", "Eliminar", "Elimina", "Supprimer", "Ta bort", "Poista"),
        .playRecording: values("播放录制", "播放錄製", "Play recording", "録画を再生", "녹화 재생", "Reproduzir gravacao", "Reproducir grabacion", "Riproduci registrazione", "Lire l'enregistrement", "Spela inspelning", "Toista tallenne"),
        .regenerateVideo: values("重新生成视频", "重新產生影片", "Regenerate video", "動画を再生成", "비디오 다시 생성", "Gerar video novamente", "Regenerar video", "Rigenera video", "Regenerer la video", "Skapa video igen", "Luo video uudelleen"),
        .regenerateSubtitles: values("重新生成字幕", "重新產生字幕", "Regenerate subtitles", "字幕を再生成", "자막 다시 생성", "Gerar legendas novamente", "Regenerar subtitulos", "Rigenera sottotitoli", "Regenerer les sous-titres", "Skapa undertexter igen", "Luo tekstitys uudelleen"),
        .showInFinder: values("在 Finder 中显示", "在 Finder 中顯示", "Show in Finder", "Finderに表示", "Finder에서 보기", "Mostrar no Finder", "Mostrar en Finder", "Mostra nel Finder", "Afficher dans Finder", "Visa i Finder", "Nayta Finderissa"),
        .skipped: values("跳过", "略過", "Skipped", "スキップ", "건너뜀", "Ignorado", "Omitido", "Saltato", "Ignore", "Hoppad over", "Ohitettu"),
        .recording: values("录制中", "錄製中", "Recording", "録画中", "녹화 중", "Gravando", "Grabando", "Registrazione", "Enregistrement", "Spelar in", "Tallennetaan"),
        .saved: values("已保存", "已儲存", "Saved", "保存済み", "저장됨", "Salvo", "Guardado", "Salvato", "Enregistre", "Sparad", "Tallennettu"),
        .renderingVideo: values("生成视频", "產生影片", "Rendering video", "動画生成中", "비디오 생성 중", "Renderizando video", "Generando video", "Rendering video", "Rendu video", "Renderar video", "Renderoidaan video"),
        .transcribing: values("生成字幕", "產生字幕", "Transcribing", "文字起こし中", "자막 생성 중", "Transcrevendo", "Transcribiendo", "Trascrizione", "Transcription", "Transkriberar", "Litteroidaan"),
        .completed: values("完成", "完成", "Complete", "完了", "완료", "Concluido", "Completado", "Completato", "Termine", "Klart", "Valmis"),
        .videoFailed: values("视频失败", "影片失敗", "Video failed", "動画失敗", "비디오 실패", "Falha no video", "Fallo de video", "Video non riuscito", "Echec video", "Video misslyckades", "Video epaonnistui"),
        .subtitleFailed: values("字幕失败", "字幕失敗", "Subtitles failed", "字幕失敗", "자막 실패", "Falha nas legendas", "Fallo de subtitulos", "Sottotitoli non riusciti", "Echec sous-titres", "Undertexter misslyckades", "Tekstitys epaonnistui"),
        .missingMicrophoneAudio: values("没有麦克风音频", "沒有麥克風音訊", "No microphone audio", "マイク音声なし", "마이크 오디오 없음", "Sem audio do microfone", "Sin audio de microfono", "Nessun audio microfono", "Pas d'audio micro", "Inget mikrofonljud", "Ei mikrofoniaanta"),
        .missingSystemAudio: values("没有系统声音", "沒有系統聲音", "No system audio", "システム音声なし", "시스템 오디오 없음", "Sem audio do sistema", "Sin audio del sistema", "Nessun audio di sistema", "Pas d'audio systeme", "Inget systemljud", "Ei jarjestelmaanta"),
        .missingSubtitleAudio: values("没有可用于字幕的音频", "沒有可用於字幕的音訊", "No audio available for subtitles", "字幕に使える音声がありません", "자막용 오디오 없음", "Sem audio para legendas", "Sin audio para subtitulos", "Nessun audio per sottotitoli", "Pas d'audio pour les sous-titres", "Inget ljud for undertexter", "Ei aanta tekstitykselle"),
        .whisperCommandNotInstalled: values("未找到内置 whisper-cli 或系统 Whisper", "找不到內建 whisper-cli 或系統 Whisper", "Bundled whisper-cli or system Whisper not found", "内蔵whisper-cliまたはシステムWhisperが見つかりません", "내장 whisper-cli 또는 시스템 Whisper 없음", "whisper-cli embutido ou Whisper do sistema nao encontrado", "No se encontro whisper-cli incluido ni Whisper del sistema", "whisper-cli incluso o Whisper di sistema non trovato", "whisper-cli integre ou Whisper systeme introuvable", "Inbyggd whisper-cli eller system-Whisper hittades inte", "Sisaanrakennettua whisper-cli:a tai jarjestelman Whisperia ei loydy"),
        .whisperMediumModelMissing: values("未找到 medium 模型", "找不到 medium 模型", "medium model not found", "mediumモデルが見つかりません", "medium 모델 없음", "Modelo medium nao encontrado", "Modelo medium no encontrado", "Modello medium non trovato", "Modele medium introuvable", "medium-modell hittades inte", "medium-mallia ei loydy"),
        .audioConverterNotInstalled: values("未找到 ffmpeg", "找不到 ffmpeg", "ffmpeg not found", "ffmpegが見つかりません", "ffmpeg 없음", "ffmpeg nao encontrado", "ffmpeg no encontrado", "ffmpeg non trovato", "ffmpeg introuvable", "ffmpeg hittades inte", "ffmpegia ei loydy"),
        .audioBoth: values("系统 + 麦克风", "系統 + 麥克風", "System + Mic", "システム + マイク", "시스템 + 마이크", "Sistema + microfone", "Sistema + microfono", "Sistema + microfono", "Systeme + micro", "System + mikrofon", "Jarjestelma + mikrofoni"),
        .audioMicrophoneOnly: values("仅麦克风", "僅麥克風", "Mic only", "マイクのみ", "마이크만", "So microfone", "Solo microfono", "Solo microfono", "Micro seul", "Endast mikrofon", "Vain mikrofoni"),
        .audioSystemOnly: values("仅系统声音", "僅系統聲音", "System only", "システム音声のみ", "시스템만", "So sistema", "Solo sistema", "Solo sistema", "Systeme seul", "Endast system", "Vain jarjestelma"),
        .audioNone: values("不录声音", "不錄聲音", "No audio", "音声なし", "오디오 없음", "Sem audio", "Sin audio", "Senza audio", "Sans audio", "Inget ljud", "Ei aanta"),
        .preparingRecording: values("准备录制", "準備錄製", "Ready to record", "録画準備完了", "녹화 준비", "Pronto para gravar", "Listo para grabar", "Pronto a registrare", "Pret a enregistrer", "Redo att spela in", "Valmis tallentamaan"),
        .preparingRecordingLong: values("正在准备录制...", "正在準備錄製...", "Preparing recording...", "録画を準備中...", "녹화 준비 중...", "Preparando gravacao...", "Preparando grabacion...", "Preparazione registrazione...", "Preparation de l'enregistrement...", "Forbereder inspelning...", "Valmistellaan tallennusta..."),
        .startFailed: values("录制启动失败", "錄製啟動失敗", "Recording failed to start", "録画の開始に失敗しました", "녹화 시작 실패", "Falha ao iniciar gravacao", "No se pudo iniciar la grabacion", "Avvio registrazione non riuscito", "Echec du demarrage", "Inspelning kunde inte starta", "Tallennuksen aloitus epaonnistui"),
        .savingRawAssets: values("正在保存原始素材...", "正在儲存原始素材...", "Saving raw assets...", "元素材を保存中...", "원본 저장 중...", "Salvando arquivos brutos...", "Guardando recursos originales...", "Salvataggio asset grezzi...", "Enregistrement des sources...", "Sparar originalfiler...", "Tallennetaan raakasisaltoa..."),
        .recorderNotStarted: values("录制器未启动", "錄製器未啟動", "Recorder was not started", "レコーダーが開始されていません", "녹화기가 시작되지 않음", "Gravador nao iniciado", "La grabadora no se inicio", "Registratore non avviato", "L'enregistreur n'a pas demarre", "Inspelaren startades inte", "Tallenninta ei kaynnistetty"),
        .mouseEventCacheLost: values("鼠标事件缓存丢失", "滑鼠事件快取遺失", "Mouse event cache was lost", "マウスイベントキャッシュが失われました", "마우스 이벤트 캐시 손실", "Cache de eventos do mouse perdida", "Se perdio la cache de eventos del raton", "Cache eventi mouse persa", "Cache des evenements souris perdue", "Cache for mushandelser saknas", "Hiiritapahtumien valimuisti katosi"),
        .saveFailed: values("录制保存失败", "錄製儲存失敗", "Recording save failed", "録画の保存に失敗", "녹화 저장 실패", "Falha ao salvar gravacao", "Fallo al guardar grabacion", "Salvataggio registrazione non riuscito", "Echec de l'enregistrement", "Inspelning kunde inte sparas", "Tallennuksen tallennus epaonnistui"),
        .rawAssetsSaved: values("原始素材已保存", "原始素材已儲存", "Raw assets saved", "元素材を保存しました", "원본 저장됨", "Arquivos brutos salvos", "Recursos originales guardados", "Asset grezzi salvati", "Sources enregistrees", "Originalfiler sparade", "Raakasisalto tallennettu"),
        .rawAssetsSavedWithWarnings: values("原始素材已保存，有警告", "原始素材已儲存，有警告", "Raw assets saved with warnings", "警告付きで元素材を保存しました", "원본 저장됨, 경고 있음", "Arquivos salvos com avisos", "Recursos guardados con advertencias", "Asset salvati con avvisi", "Sources enregistrees avec avertissements", "Original sparade med varningar", "Raakasisalto tallennettu varoituksin"),
        .projectSaveFailed: values("项目保存失败：%@", "項目儲存失敗：%@", "Project save failed: %@", "プロジェクト保存失敗: %@", "프로젝트 저장 실패: %@", "Falha ao salvar projeto: %@", "Fallo al guardar proyecto: %@", "Salvataggio progetto non riuscito: %@", "Echec de sauvegarde du projet : %@", "Projekt kunde inte sparas: %@", "Projektin tallennus epaonnistui: %@"),
        .fileGeneratedProjectSaveFailed: values("录制文件已生成，项目保存失败", "錄製檔案已產生，項目儲存失敗", "Recording files were created, but project save failed", "録画ファイルは生成されましたが、プロジェクト保存に失敗", "녹화 파일 생성됨, 프로젝트 저장 실패", "Arquivos criados, mas o projeto nao foi salvo", "Archivos creados, pero fallo guardar el proyecto", "File creati, ma salvataggio progetto non riuscito", "Fichiers crees, mais sauvegarde du projet echouee", "Filer skapades men projektet sparades inte", "Tiedostot luotu, mutta projektin tallennus epaonnistui"),
        .checkingMediumModel: values("正在检查 medium 模型...", "正在檢查 medium 模型...", "Checking medium model...", "mediumモデルを確認中...", "medium 모델 확인 중...", "Verificando modelo medium...", "Comprobando modelo medium...", "Controllo modello medium...", "Verification du modele medium...", "Kontrollerar medium-modell...", "Tarkistetaan medium-mallia..."),
        .mediumModelReady: values("medium 模型已就绪", "medium 模型已就緒", "medium model is ready", "mediumモデルは準備済み", "medium 모델 준비됨", "Modelo medium pronto", "Modelo medium listo", "Modello medium pronto", "Modele medium pret", "medium-modell klar", "medium-malli valmis"),
        .mediumModelNotInstalled: values("未安装 whisper.cpp medium 模型", "未安裝 whisper.cpp medium 模型", "whisper.cpp medium model is not installed", "whisper.cpp mediumモデル未インストール", "whisper.cpp medium 모델 미설치", "Modelo medium do whisper.cpp nao instalado", "Modelo medium de whisper.cpp no instalado", "Modello medium whisper.cpp non installato", "Modele medium whisper.cpp non installe", "whisper.cpp medium-modell ar inte installerad", "whisper.cpp medium-mallia ei ole asennettu"),
        .downloadingMediumModelLarge: values("正在下载 medium 模型（约 1.5GB）...", "正在下載 medium 模型（約 1.5GB）...", "Downloading medium model (about 1.5 GB)...", "mediumモデルをダウンロード中（約1.5GB）...", "medium 모델 다운로드 중(약 1.5GB)...", "Baixando modelo medium (cerca de 1,5 GB)...", "Descargando modelo medium (aprox. 1,5 GB)...", "Download modello medium (circa 1,5 GB)...", "Telechargement du modele medium (env. 1,5 Go)...", "Hamtar medium-modell (ca 1,5 GB)...", "Ladataan medium-mallia (noin 1,5 Gt)..."),
        .downloadingMediumModelProgress: values("正在下载 medium 模型 %d%%", "正在下載 medium 模型 %d%%", "Downloading medium model %d%%", "mediumモデルをダウンロード中 %d%%", "medium 모델 다운로드 중 %d%%", "Baixando modelo medium %d%%", "Descargando modelo medium %d%%", "Download modello medium %d%%", "Telechargement du modele medium %d%%", "Hamtar medium-modell %d%%", "Ladataan medium-mallia %d%%"),
        .downloadingMediumModel: values("正在下载 medium 模型...", "正在下載 medium 模型...", "Downloading medium model...", "mediumモデルをダウンロード中...", "medium 모델 다운로드 중...", "Baixando modelo medium...", "Descargando modelo medium...", "Download modello medium...", "Telechargement du modele medium...", "Hamtar medium-modell...", "Ladataan medium-mallia..."),
        .mediumModelDownloaded: values("medium 模型已下载", "medium 模型已下載", "medium model downloaded", "mediumモデルをダウンロードしました", "medium 모델 다운로드됨", "Modelo medium baixado", "Modelo medium descargado", "Modello medium scaricato", "Modele medium telecharge", "medium-modell hamtad", "medium-malli ladattu"),
        .subtitleModelReady: values("字幕模型已就绪", "字幕模型已就緒", "Subtitle model is ready", "字幕モデルは準備済み", "자막 모델 준비됨", "Modelo de legendas pronto", "Modelo de subtitulos listo", "Modello sottotitoli pronto", "Modele de sous-titres pret", "Undertextmodell klar", "Tekstitysmalli valmis"),
        .mediumModelDownloadFailed: values("medium 模型下载失败", "medium 模型下載失敗", "medium model download failed", "mediumモデルのダウンロード失敗", "medium 모델 다운로드 실패", "Falha ao baixar modelo medium", "Fallo al descargar modelo medium", "Download modello medium non riuscito", "Echec du telechargement du modele medium", "Hamtning av medium-modell misslyckades", "medium-mallin lataus epaonnistui"),
        .subtitleModelUnavailable: values("字幕模型不可用", "字幕模型不可用", "Subtitle model unavailable", "字幕モデルは利用不可", "자막 모델 사용 불가", "Modelo de legendas indisponivel", "Modelo de subtitulos no disponible", "Modello sottotitoli non disponibile", "Modele de sous-titres indisponible", "Undertextmodell ej tillganglig", "Tekstitysmalli ei ole kaytettavissa"),
        .startFailedWithDetail: values("录制启动失败：%@", "錄製啟動失敗：%@", "Recording failed to start: %@", "録画開始失敗: %@", "녹화 시작 실패: %@", "Falha ao iniciar gravacao: %@", "Fallo al iniciar grabacion: %@", "Avvio registrazione non riuscito: %@", "Echec du demarrage : %@", "Inspelning kunde inte starta: %@", "Tallennuksen aloitus epaonnistui: %@"),
        .screenPermissionStatus: values("需要屏幕录制权限", "需要螢幕錄製權限", "Screen recording permission required", "画面収録権限が必要", "화면 녹화 권한 필요", "Permissao de gravacao de tela necessaria", "Se requiere permiso de grabacion de pantalla", "Serve il permesso di registrazione schermo", "Autorisation d'enregistrement d'ecran requise", "Skarm inspelningsbehorighet kravs", "Nayton tallennusoikeus vaaditaan"),
        .screenPermissionDenied: values("未获得屏幕录制权限。请在系统设置中允许 SmartRecord 录制屏幕，然后重新开始录制。", "未取得螢幕錄製權限。請在系統設定中允許 SmartRecord 錄製螢幕，然後重新開始錄製。", "Screen recording permission was not granted. Allow SmartRecord in System Settings, then start again.", "画面収録権限がありません。システム設定でSmartRecordを許可してから再開してください。", "화면 녹화 권한이 없습니다. 시스템 설정에서 SmartRecord를 허용한 뒤 다시 시작하세요.", "Permissao de gravacao de tela nao concedida. Permita o SmartRecord nos Ajustes e tente de novo.", "No se concedio permiso de grabacion de pantalla. Permite SmartRecord en Ajustes y vuelve a iniciar.", "Permesso di registrazione schermo non concesso. Consenti SmartRecord nelle impostazioni e riprova.", "Autorisation d'enregistrement d'ecran non accordee. Autorisez SmartRecord dans les reglages puis recommencez.", "Skarm inspelningsbehorighet saknas. Tillat SmartRecord i installningar och starta igen.", "Nayton tallennusoikeutta ei annettu. Salli SmartRecord asetuksissa ja aloita uudelleen."),
        .noRecordableDisplay: values("找不到可录制的显示器。", "找不到可錄製的顯示器。", "No recordable display was found.", "録画可能なディスプレイが見つかりません。", "녹화 가능한 디스플레이 없음.", "Nenhuma tela gravavel encontrada.", "No se encontro una pantalla grabable.", "Nessun display registrabile trovato.", "Aucun ecran enregistrable trouve.", "Ingen inspelningsbar skarm hittades.", "Tallennettavaa nayttoa ei loytynyt."),
        .recordingTooShort: values("录制时间太短，没有捕捉到可保存的视频帧。请至少录制 2 秒后再停止。", "錄製時間太短，未捕捉到可儲存的影片影格。請至少錄製 2 秒後再停止。", "Recording was too short to save video frames. Record for at least 2 seconds before stopping.", "録画が短すぎて保存できるフレームがありません。2秒以上録画してから停止してください。", "녹화가 너무 짧아 저장할 프레임이 없습니다. 최소 2초 이상 녹화하세요.", "A gravacao foi curta demais. Grave por pelo menos 2 segundos antes de parar.", "La grabacion fue demasiado corta. Graba al menos 2 segundos antes de detener.", "Registrazione troppo breve. Registra almeno 2 secondi prima di fermare.", "L'enregistrement est trop court. Enregistrez au moins 2 secondes avant d'arreter.", "Inspelningen var for kort. Spela in minst 2 sekunder innan du stoppar.", "Tallennus oli liian lyhyt. Tallenna vahintaan 2 sekuntia ennen pysaytysta."),
        .screenPermissionRecovery: values("打开 系统设置 > 隐私与安全性 > 屏幕录制，勾选 SmartRecord。若已勾选，请关闭后重新打开本应用。", "開啟 系統設定 > 隱私權與安全性 > 螢幕錄製，勾選 SmartRecord。若已勾選，請關閉後重新開啟本應用。", "Open System Settings > Privacy & Security > Screen Recording and enable SmartRecord. If already enabled, restart this app.", "システム設定 > プライバシーとセキュリティ > 画面収録でSmartRecordを有効にしてください。既に有効ならアプリを再起動してください。", "시스템 설정 > 개인정보 보호 및 보안 > 화면 녹화에서 SmartRecord를 켜세요. 이미 켰다면 앱을 다시 여세요.", "Abra Ajustes > Privacidade e Seguranca > Gravacao de Tela e ative SmartRecord. Se ja estiver ativo, reinicie o app.", "Abre Ajustes > Privacidad y seguridad > Grabacion de pantalla y activa SmartRecord. Si ya esta activo, reinicia la app.", "Apri Impostazioni > Privacy e sicurezza > Registrazione schermo e abilita SmartRecord. Se gia attivo, riavvia l'app.", "Ouvrez Reglages > Confidentialite et securite > Enregistrement d'ecran et activez SmartRecord. Si deja actif, redemarrez l'app.", "Oppna Systeminstallningar > Integritet och sakerhet > Skarminspelning och aktivera SmartRecord. Starta om appen om det redan ar aktivt.", "Avaa Asetukset > Tietosuoja ja suojaus > Nayton tallennus ja ota SmartRecord kayttoon. Jos se on jo paalla, kaynnista appi uudelleen."),
        .missingAssetDirectory: values("缺少项目素材目录", "缺少項目素材目錄", "Project asset directory is missing", "プロジェクト素材フォルダがありません", "프로젝트 자료 폴더 없음", "Pasta de recursos do projeto ausente", "Falta la carpeta de recursos del proyecto", "Cartella asset progetto mancante", "Dossier des ressources du projet manquant", "Projektets resursmapp saknas", "Projektin resurssikansio puuttuu"),
        .unknownWriterError: values("未知写入错误", "未知寫入錯誤", "Unknown writing error", "不明な書き込みエラー", "알 수 없는 쓰기 오류", "Erro de gravacao desconhecido", "Error de escritura desconocido", "Errore di scrittura sconosciuto", "Erreur d'ecriture inconnue", "Okant skrivfel", "Tuntematon kirjoitusvirhe"),
        .writerFailed: values("录制文件写入失败：%@", "錄製檔案寫入失敗：%@", "Recording file write failed: %@", "録画ファイルの書き込み失敗: %@", "녹화 파일 쓰기 실패: %@", "Falha ao gravar arquivo: %@", "Fallo al escribir archivo: %@", "Scrittura file registrazione non riuscita: %@", "Echec d'ecriture du fichier : %@", "Inspelningsfil kunde inte skrivas: %@", "Tallennetiedoston kirjoitus epaonnistui: %@"),
        .missingScreenVideo: values("缺少 screen.mov，无法生成最终视频。", "缺少 screen.mov，無法產生最終影片。", "screen.mov is missing, so final video cannot be generated.", "screen.movがないため最終動画を生成できません。", "screen.mov가 없어 최종 비디오를 만들 수 없습니다.", "screen.mov ausente; nao e possivel gerar o video final.", "Falta screen.mov; no se puede generar el video final.", "screen.mov mancante; impossibile generare il video finale.", "screen.mov manque ; impossible de generer la video finale.", "screen.mov saknas, final video kan inte skapas.", "screen.mov puuttuu, lopullista videota ei voi luoda."),
        .noVideoTrack: values("screen.mov 中没有可用视频轨道。", "screen.mov 中沒有可用影片軌。", "screen.mov has no usable video track.", "screen.movに使用可能な動画トラックがありません。", "screen.mov에 사용 가능한 비디오 트랙 없음.", "screen.mov nao tem faixa de video utilizavel.", "screen.mov no tiene pista de video usable.", "screen.mov non ha tracce video utilizzabili.", "screen.mov ne contient aucune piste video utilisable.", "screen.mov har inget anvandbart videospar.", "screen.movissa ei ole kaytettavaa videoraitaa."),
        .exportUnavailable: values("当前系统无法创建视频导出任务。", "目前系統無法建立影片匯出任務。", "This system cannot create a video export task.", "このシステムでは動画書き出しを作成できません。", "현재 시스템에서 비디오 내보내기를 만들 수 없습니다.", "Este sistema nao pode criar a exportacao de video.", "Este sistema no puede crear la exportacion de video.", "Il sistema non puo creare l'esportazione video.", "Ce systeme ne peut pas creer l'export video.", "Systemet kan inte skapa videoexport.", "Jarjestelma ei voi luoda videon vientia."),
        .exportFailed: values("最终视频导出失败：%@", "最終影片匯出失敗：%@", "Final video export failed: %@", "最終動画の書き出し失敗: %@", "최종 비디오 내보내기 실패: %@", "Falha ao exportar video final: %@", "Fallo al exportar video final: %@", "Esportazione video finale non riuscita: %@", "Echec de l'export final : %@", "Slutlig videoexport misslyckades: %@", "Lopullisen videon vienti epaonnistui: %@"),
        .unknownError: values("未知错误", "未知錯誤", "Unknown error", "不明なエラー", "알 수 없는 오류", "Erro desconhecido", "Error desconocido", "Errore sconosciuto", "Erreur inconnue", "Okant fel", "Tuntematon virhe"),
        .missingWhisperCommandError: values("未找到内置 whisper-cli，也未找到系统 Whisper 命令。", "找不到內建 whisper-cli，也找不到系統 Whisper 命令。", "Bundled whisper-cli and system Whisper command were not found.", "内蔵whisper-cliもシステムWhisperコマンドも見つかりません。", "내장 whisper-cli와 시스템 Whisper 명령을 찾을 수 없습니다.", "whisper-cli embutido e comando Whisper do sistema nao encontrados.", "No se encontro whisper-cli incluido ni comando Whisper del sistema.", "whisper-cli incluso e comando Whisper di sistema non trovati.", "whisper-cli integre et commande Whisper systeme introuvables.", "Inbyggd whisper-cli och systemets Whisper-kommando hittades inte.", "Sisaanrakennettua whisper-cli:a tai jarjestelman Whisper-komentoa ei loydy."),
        .missingSubtitleAudioError: values("缺少可用于字幕的音频文件。", "缺少可用於字幕的音訊檔。", "Missing audio file for subtitles.", "字幕用の音声ファイルがありません。", "자막용 오디오 파일 없음.", "Arquivo de audio para legendas ausente.", "Falta archivo de audio para subtitulos.", "File audio per sottotitoli mancante.", "Fichier audio pour sous-titres manquant.", "Ljudfil for undertexter saknas.", "Tekstityksen aanitiedosto puuttuu."),
        .missingMediumModelError: values("未找到 whisper.cpp 的 medium 模型。请设置 SMARTRECORD_WHISPER_MODEL，或放置 ggml-medium.bin。", "找不到 whisper.cpp 的 medium 模型。請設定 SMARTRECORD_WHISPER_MODEL，或放置 ggml-medium.bin。", "whisper.cpp medium model was not found. Set SMARTRECORD_WHISPER_MODEL or place ggml-medium.bin.", "whisper.cppのmediumモデルが見つかりません。SMARTRECORD_WHISPER_MODELを設定するかggml-medium.binを配置してください。", "whisper.cpp medium 모델이 없습니다. SMARTRECORD_WHISPER_MODEL을 설정하거나 ggml-medium.bin을 넣으세요.", "Modelo medium do whisper.cpp nao encontrado. Defina SMARTRECORD_WHISPER_MODEL ou coloque ggml-medium.bin.", "No se encontro el modelo medium de whisper.cpp. Define SMARTRECORD_WHISPER_MODEL o coloca ggml-medium.bin.", "Modello medium di whisper.cpp non trovato. Imposta SMARTRECORD_WHISPER_MODEL o inserisci ggml-medium.bin.", "Modele medium whisper.cpp introuvable. Definissez SMARTRECORD_WHISPER_MODEL ou placez ggml-medium.bin.", "whisper.cpp medium-modell hittades inte. Stall in SMARTRECORD_WHISPER_MODEL eller lagg ggml-medium.bin.", "whisper.cpp medium-mallia ei loytynyt. Aseta SMARTRECORD_WHISPER_MODEL tai sijoita ggml-medium.bin."),
        .missingAudioConverterError: values("未找到 ffmpeg，无法为 whisper.cpp 转换字幕音频。", "找不到 ffmpeg，無法為 whisper.cpp 轉換字幕音訊。", "ffmpeg was not found, so subtitle audio cannot be converted for whisper.cpp.", "ffmpegが見つからず、whisper.cpp用に字幕音声を変換できません。", "ffmpeg가 없어 whisper.cpp용 자막 오디오를 변환할 수 없습니다.", "ffmpeg nao encontrado; nao e possivel converter audio para whisper.cpp.", "No se encontro ffmpeg; no se puede convertir audio para whisper.cpp.", "ffmpeg non trovato; impossibile convertire audio per whisper.cpp.", "ffmpeg introuvable ; impossible de convertir l'audio pour whisper.cpp.", "ffmpeg hittades inte; kan inte konvertera ljud for whisper.cpp.", "ffmpegia ei loydy; aanta ei voi muuntaa whisper.cpp:lle."),
        .whisperFailed: values("Whisper 转录失败（%d）：%@", "Whisper 轉錄失敗（%d）：%@", "Whisper transcription failed (%d): %@", "Whisper文字起こし失敗（%d）: %@", "Whisper 전사 실패(%d): %@", "Transcricao Whisper falhou (%d): %@", "La transcripcion Whisper fallo (%d): %@", "Trascrizione Whisper non riuscita (%d): %@", "Transcription Whisper echouee (%d) : %@", "Whisper-transkribering misslyckades (%d): %@", "Whisper-litterointi epaonnistui (%d): %@"),
        .unknownWhisperError: values("未知 Whisper 错误", "未知 Whisper 錯誤", "Unknown Whisper error", "不明なWhisperエラー", "알 수 없는 Whisper 오류", "Erro Whisper desconhecido", "Error Whisper desconocido", "Errore Whisper sconosciuto", "Erreur Whisper inconnue", "Okant Whisper-fel", "Tuntematon Whisper-virhe"),
        .whisperDidNotGenerateVTT: values("Whisper 未生成 VTT 文件", "Whisper 未產生 VTT 檔案", "Whisper did not generate a VTT file", "WhisperがVTTファイルを生成しませんでした", "Whisper가 VTT 파일을 생성하지 않음", "Whisper nao gerou arquivo VTT", "Whisper no genero archivo VTT", "Whisper non ha generato un file VTT", "Whisper n'a pas genere de fichier VTT", "Whisper skapade ingen VTT-fil", "Whisper ei luonut VTT-tiedostoa"),
        .mediumModelIncomplete: values("medium 模型文件不完整，请重试下载。", "medium 模型檔案不完整，請重新下載。", "medium model file is incomplete. Please download it again.", "mediumモデルファイルが不完全です。再ダウンロードしてください。", "medium 모델 파일이 불완전합니다. 다시 다운로드하세요.", "Arquivo do modelo medium incompleto. Baixe novamente.", "El archivo del modelo medium esta incompleto. Descargalo de nuevo.", "File modello medium incompleto. Scaricalo di nuovo.", "Le fichier du modele medium est incomplet. Telechargez-le a nouveau.", "medium-modellfilen ar ofullstandig. Hamta den igen.", "medium-mallitiedosto on vajaa. Lataa se uudelleen."),
        .mediumModelServerFailed: values("medium 模型下载失败，服务器返回 %d。", "medium 模型下載失敗，伺服器返回 %d。", "medium model download failed; server returned %d.", "mediumモデルのダウンロード失敗。サーバー応答: %d。", "medium 모델 다운로드 실패, 서버 응답 %d.", "Download do modelo medium falhou; servidor retornou %d.", "Fallo la descarga del modelo medium; el servidor devolvio %d.", "Download modello medium non riuscito; il server ha restituito %d.", "Echec du telechargement du modele medium ; serveur %d.", "Hamtning av medium-modell misslyckades; servern returnerade %d.", "medium-mallin lataus epaonnistui; palvelin palautti %d.")
    ]
}

nonisolated enum AppLanguageStore {
    static let userDefaultsKey = "appLanguage"

    static var currentLanguage: AppLanguage {
        get {
            let rawValue = UserDefaults.standard.string(forKey: userDefaultsKey)
            return AppLanguage(rawValue: rawValue ?? "") ?? .zhHans
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: userDefaultsKey)
        }
    }
}
