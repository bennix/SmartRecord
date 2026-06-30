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
    case appTagline
    case language
    case audioMode
    case recordingFrameRate
    case capturePipeline
    case screenAndSystemAudio
    case screenRecordingPermissionRequired
    case openSettings
    case mouseClickSmartFocus
    case clickAreaAutoZoom
    case audioMix
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
    case waitingMP4
    case noClickEvents
    case play
    case video
    case delete
    case playRecording
    case regenerateVideo
    case showInFinder
    case skipped
    case recording
    case saved
    case renderingVideo
    case completed
    case videoFailed
    case missingMicrophoneAudio
    case missingSystemAudio
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
        .appTagline: values("屏幕、系统声音、麦克风、SmartFocus", "螢幕、系統聲音、麥克風、SmartFocus", "Screen, system audio, microphone, SmartFocus", "画面、システム音声、マイク、SmartFocus", "화면, 시스템 오디오, 마이크, SmartFocus", "Tela, audio do sistema, microfone, SmartFocus", "Pantalla, audio del sistema, micrófono, SmartFocus", "Schermo, audio di sistema, microfono, SmartFocus", "Ecran, audio systeme, micro, SmartFocus", "Skarm, systemljud, mikrofon, SmartFocus", "Naytto, jarjestelmaaani, mikrofoni, SmartFocus"),
        .language: values("语言", "語言", "Language", "言語", "언어", "Idioma", "Idioma", "Lingua", "Langue", "Sprak", "Kieli"),
        .audioMode: values("录音模式", "錄音模式", "Audio mode", "音声モード", "오디오 모드", "Modo de audio", "Modo de audio", "Modalita audio", "Mode audio", "Ljudlage", "Aanentila"),
        .recordingFrameRate: values("录制帧率", "錄製影格率", "Recording frame rate", "録画フレームレート", "녹화 프레임 속도", "Taxa de quadros", "Velocidad de fotogramas", "Frequenza fotogrammi", "Frequence d'image", "Bildfrekvens", "Kuvataajuus"),
        .capturePipeline: values("录制链路", "錄製鏈路", "Capture pipeline", "キャプチャ経路", "캡처 파이프라인", "Pipeline de captura", "Canal de captura", "Pipeline di acquisizione", "Pipeline de capture", "Inspelningskedja", "Tallennusketju"),
        .screenAndSystemAudio: values("屏幕与系统声音", "螢幕與系統聲音", "Screen and system audio", "画面とシステム音声", "화면 및 시스템 오디오", "Tela e audio do sistema", "Pantalla y audio del sistema", "Schermo e audio di sistema", "Ecran et audio systeme", "Skarm och systemljud", "Naytto ja jarjestelmaaani"),
        .screenRecordingPermissionRequired: values("需要屏幕录制权限", "需要螢幕錄製權限", "Screen recording permission required", "画面収録権限が必要です", "화면 녹화 권한 필요", "Permissao de gravacao de tela necessaria", "Se requiere permiso de grabacion de pantalla", "Serve il permesso di registrazione schermo", "Autorisation d'enregistrement d'ecran requise", "Skarm inspelningsbehorighet kravs", "Nayton tallennusoikeus vaaditaan"),
        .openSettings: values("打开设置", "開啟設定", "Open Settings", "設定を開く", "설정 열기", "Abrir Ajustes", "Abrir ajustes", "Apri impostazioni", "Ouvrir les reglages", "Oppna installningar", "Avaa asetukset"),
        .mouseClickSmartFocus: values("鼠标点击 SmartFocus", "滑鼠點擊 SmartFocus", "Mouse-click SmartFocus", "マウスクリック SmartFocus", "마우스 클릭 SmartFocus", "SmartFocus por clique", "SmartFocus con clic", "SmartFocus al clic", "SmartFocus au clic", "SmartFocus vid klick", "SmartFocus klikkauksesta"),
        .clickAreaAutoZoom: values("点击区域自动放大回弹", "點擊區域自動放大回彈", "Click area auto-zooms and returns", "クリック領域を自動ズームして戻す", "클릭 영역 자동 확대 후 복귀", "A area clicada amplia e volta", "El area clicada se acerca y vuelve", "L'area cliccata si ingrandisce e torna", "La zone cliquee zoome puis revient", "Klickomradet zoomas och atergar", "Klikattu alue zoomaa ja palaa"),
        .audioMix: values("音频混合", "音訊混合", "Audio mix", "音声ミックス", "오디오 믹스", "Mixagem de audio", "Mezcla de audio", "Mix audio", "Mixage audio", "Ljudmix", "Aanen miksaus"),
        .recordingProjects: values("录制项目", "錄製項目", "Recording projects", "録画プロジェクト", "녹화 프로젝트", "Projetos de gravacao", "Proyectos de grabacion", "Progetti registrati", "Projets d'enregistrement", "Inspelningsprojekt", "Tallennusprojektit"),
        .projectsDescription: values("点击任意项目播放 final.mp4；若未生成，则打开原始 screen.mov。", "點擊任一項目播放 final.mp4；若未產生，則開啟原始 screen.mov。", "Click any project to play final.mp4; if it is missing, the raw screen.mov opens.", "任意のプロジェクトをクリックしてfinal.mp4を再生します。未生成なら元のscreen.movを開きます。", "프로젝트를 클릭하면 final.mp4를 재생하고, 없으면 원본 screen.mov를 엽니다.", "Clique em um projeto para reproduzir final.mp4; se faltar, abre o screen.mov original.", "Haz clic en un proyecto para reproducir final.mp4; si falta, se abre screen.mov original.", "Fai clic su un progetto per riprodurre final.mp4; se manca, apre screen.mov originale.", "Cliquez sur un projet pour lire final.mp4 ; s'il manque, screen.mov brut s'ouvre.", "Klicka pa ett projekt for att spela final.mp4; saknas den oppnas screen.mov.", "Avaa final.mp4 napsauttamalla projektia; jos se puuttuu, avataan raaka screen.mov."),
        .projectsMetric: values("项目", "項目", "Projects", "プロジェクト", "프로젝트", "Projetos", "Proyectos", "Progetti", "Projets", "Projekt", "Projektit"),
        .eventsMetric: values("事件", "事件", "Events", "イベント", "이벤트", "Eventos", "Eventos", "Eventi", "Evenements", "Handelser", "Tapahtumat"),
        .noRecordings: values("还没有录制", "尚未錄製", "No recordings yet", "録画はまだありません", "아직 녹화 없음", "Ainda sem gravacoes", "Aun no hay grabaciones", "Nessuna registrazione", "Aucun enregistrement", "Inga inspelningar an", "Ei tallenteita viela"),
        .noRecordingsDescription: values("开始录制后，这里会显示原始素材和 SmartFocus MP4 状态。", "開始錄製後，這裡會顯示原始素材與 SmartFocus MP4 狀態。", "After recording starts, raw assets and SmartFocus MP4 status appear here.", "録画を開始すると、元素材とSmartFocus MP4の状態がここに表示されます。", "녹화를 시작하면 원본과 SmartFocus MP4 상태가 여기에 표시됩니다.", "Apos gravar, os arquivos brutos e o status do MP4 SmartFocus aparecem aqui.", "Al grabar, aqui veras recursos originales y el estado de MP4 SmartFocus.", "Dopo la registrazione vedrai asset grezzi e stato MP4 SmartFocus.", "Apres l'enregistrement, les sources et l'etat MP4 SmartFocus s'affichent ici.", "Efter inspelning visas originalfiler och SmartFocus MP4-status har.", "Tallennuksen jalkeen raakasisalto ja SmartFocus MP4 -tila nakyvat tassa."),
        .starting: values("正在启动", "正在啟動", "Starting", "開始中", "시작 중", "Iniciando", "Iniciando", "Avvio", "Demarrage", "Startar", "Kaynnistyy"),
        .stopRecording: values("停止录制", "停止錄製", "Stop recording", "録画を停止", "녹화 중지", "Parar gravacao", "Detener grabacion", "Ferma registrazione", "Arreter l'enregistrement", "Stoppa inspelning", "Pysayta tallennus"),
        .startRecording: values("开始录制", "開始錄製", "Start recording", "録画を開始", "녹화 시작", "Iniciar gravacao", "Iniciar grabacion", "Avvia registrazione", "Demarrer l'enregistrement", "Starta inspelning", "Aloita tallennus"),
        .startedAt: values("开始于 %@", "開始於 %@", "Started at %@", "%@ に開始", "%@ 시작", "Iniciou as %@", "Inicio a las %@", "Avviato alle %@", "Demarre a %@", "Startade %@", "Alkoi %@"),
        .waitingMP4: values("等待 MP4", "等待 MP4", "Waiting for MP4", "MP4待機中", "MP4 대기 중", "Aguardando MP4", "Esperando MP4", "In attesa di MP4", "En attente du MP4", "Vantar pa MP4", "Odottaa MP4:aa"),
        .noClickEvents: values("无点击事件", "無點擊事件", "No click events", "クリックイベントなし", "클릭 이벤트 없음", "Sem eventos de clique", "Sin eventos de clic", "Nessun clic", "Aucun clic", "Inga klickhandelser", "Ei klikkaustapahtumia"),
        .play: values("播放", "播放", "Play", "再生", "재생", "Reproduzir", "Reproducir", "Riproduci", "Lire", "Spela", "Toista"),
        .video: values("视频", "影片", "Video", "動画", "비디오", "Video", "Video", "Video", "Video", "Video", "Video"),
        .delete: values("删除", "刪除", "Delete", "削除", "삭제", "Excluir", "Eliminar", "Elimina", "Supprimer", "Ta bort", "Poista"),
        .playRecording: values("播放录制", "播放錄製", "Play recording", "録画を再生", "녹화 재생", "Reproduzir gravacao", "Reproducir grabacion", "Riproduci registrazione", "Lire l'enregistrement", "Spela inspelning", "Toista tallenne"),
        .regenerateVideo: values("重新生成视频", "重新產生影片", "Regenerate video", "動画を再生成", "비디오 다시 생성", "Gerar video novamente", "Regenerar video", "Rigenera video", "Regenerer la video", "Skapa video igen", "Luo video uudelleen"),
        .showInFinder: values("在 Finder 中显示", "在 Finder 中顯示", "Show in Finder", "Finderに表示", "Finder에서 보기", "Mostrar no Finder", "Mostrar en Finder", "Mostra nel Finder", "Afficher dans Finder", "Visa i Finder", "Nayta Finderissa"),
        .skipped: values("跳过", "略過", "Skipped", "スキップ", "건너뜀", "Ignorado", "Omitido", "Saltato", "Ignore", "Hoppad over", "Ohitettu"),
        .recording: values("录制中", "錄製中", "Recording", "録画中", "녹화 중", "Gravando", "Grabando", "Registrazione", "Enregistrement", "Spelar in", "Tallennetaan"),
        .saved: values("已保存", "已儲存", "Saved", "保存済み", "저장됨", "Salvo", "Guardado", "Salvato", "Enregistre", "Sparad", "Tallennettu"),
        .renderingVideo: values("生成视频", "產生影片", "Rendering video", "動画生成中", "비디오 생성 중", "Renderizando video", "Generando video", "Rendering video", "Rendu video", "Renderar video", "Renderoidaan video"),
        .completed: values("完成", "完成", "Complete", "完了", "완료", "Concluido", "Completado", "Completato", "Termine", "Klart", "Valmis"),
        .videoFailed: values("视频失败", "影片失敗", "Video failed", "動画失敗", "비디오 실패", "Falha no video", "Fallo de video", "Video non riuscito", "Echec video", "Video misslyckades", "Video epaonnistui"),
        .missingMicrophoneAudio: values("没有麦克风音频", "沒有麥克風音訊", "No microphone audio", "マイク音声なし", "마이크 오디오 없음", "Sem audio do microfone", "Sin audio de microfono", "Nessun audio microfono", "Pas d'audio micro", "Inget mikrofonljud", "Ei mikrofoniaanta"),
        .missingSystemAudio: values("没有系统声音", "沒有系統聲音", "No system audio", "システム音声なし", "시스템 오디오 없음", "Sem audio do sistema", "Sin audio del sistema", "Nessun audio di sistema", "Pas d'audio systeme", "Inget systemljud", "Ei jarjestelmaanta"),
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
