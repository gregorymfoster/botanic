import Foundation

/// Centralized, stable automation identifiers for UI tests and agent tooling. Every interactive
/// element in `BotanicApp/Views` should carry one of these via `.accessibilityIdentifier(...)`.
/// Agents/UI tests must match on these identifiers, never on user-visible copy, so the copy can
/// change freely without breaking automation.
///
/// Dot-separated, lowerCamel convention: `screen.element` (e.g. `today.addSupplement`).
enum AccessibilityID {

    /// Root tab bar (RootView).
    enum Tab {
        static let today = "tab.today"
        static let history = "tab.history"
        static let settings = "tab.settings"
    }

    /// TodayView — idle state, live state, and shared supplement rows.
    enum Today {
        static let addSupplement = "today.addSupplement"
        static let quickAddPrefix = "today.quickAdd"
        static let endExperience = "today.endExperience"
        static let checkIn = "today.checkIn"
        static let note = "today.note"
        static let lastCheckInSnippet = "today.lastCheckInSnippet"
        static let timelineDone = "today.timelineDone"
        static let supplementRowPrefix = "today.supplementRow"
        static let scheduledSupplementRowPrefix = "today.scheduledSupplementRow"
    }

    /// AddSupplementView.
    enum AddSupplement {
        static let close = "addSupplement.close"
        static let nameField = "addSupplement.nameField"
        static let howTakingField = "addSupplement.howTakingField"
        static let intentionField = "addSupplement.intentionField"
        static let recentChipPrefix = "addSupplement.recentChip"
        static let scheduleToggle = "addSupplement.scheduleToggle"
        static let scheduledForPicker = "addSupplement.scheduledForPicker"
        static let save = "addSupplement.save"
        static let saveToolbar = "addSupplement.saveToolbar"
    }

    /// CheckInView.
    enum CheckIn {
        static let cancel = "checkIn.cancel"
        static let valenceSlider = "checkIn.valenceSlider"
        static let intensitySlider = "checkIn.intensitySlider"
        static let bodyLoadSlider = "checkIn.bodyLoadSlider"
        static let tagChipPrefix = "checkIn.tagChip"
        static let noteField = "checkIn.noteField"
        static let save = "checkIn.save"
    }

    /// EndExperienceView.
    enum EndExperience {
        static let notYet = "endExperience.notYet"
        static let confirmEnd = "endExperience.confirmEnd"
        static let titleField = "endExperience.titleField"
        static let subtitleField = "endExperience.subtitleField"
        static let saveToHistory = "endExperience.saveToHistory"
        static let keepRunning = "endExperience.keepRunning"
    }

    /// NoteView.
    enum Note {
        static let cancel = "note.cancel"
        static let textEditor = "note.textEditor"
        static let send = "note.send"
        static let saveToolbar = "note.saveToolbar"
    }

    /// HistoryView + ExperienceRow.
    enum History {
        static let insightsCard = "history.insightsCard"
        static let editToggle = "history.editToggle"
        static let experienceRowPrefix = "history.experienceRow"
        static let deleteSwipePrefix = "history.deleteSwipe"
        static let renameSwipePrefix = "history.renameSwipe"
        static let renameCancel = "history.renameCancel"
        static let renameSave = "history.renameSave"
        static let renameField = "history.renameField"
        static let deleteConfirm = "history.deleteConfirm"
        static let deleteKeep = "history.deleteKeep"
    }

    /// ExperienceDetailView.
    enum ExperienceDetail {
        static let moreActions = "experienceDetail.moreActions"
        static let rename = "experienceDetail.rename"
        static let share = "experienceDetail.share"
        static let delete = "experienceDetail.delete"
        static let deleteConfirm = "experienceDetail.deleteConfirm"
        static let deleteKeep = "experienceDetail.deleteKeep"
        static let titleButton = "experienceDetail.titleButton"
        static let titleField = "experienceDetail.titleField"
        static let subtitleButton = "experienceDetail.subtitleButton"
        static let subtitleField = "experienceDetail.subtitleField"
        static let titleEditCancel = "experienceDetail.titleEditCancel"
        static let titleEditSave = "experienceDetail.titleEditSave"
        static let editSupplements = "experienceDetail.editSupplements"
        static let supplementHowTakingFieldPrefix = "experienceDetail.supplementHowTakingField"
        static let supplementTakenAtPickerPrefix = "experienceDetail.supplementTakenAtPicker"
        static let noteButton = "experienceDetail.noteButton"
        static let noteField = "experienceDetail.noteField"
        static let noteEditCancel = "experienceDetail.noteEditCancel"
        static let noteEditSave = "experienceDetail.noteEditSave"
        static let shareRow = "experienceDetail.shareRow"
    }

    /// InsightsView.
    enum Insights {
        static let feltTrendChart = "insights.feltTrendChart"
    }

    /// SettingsView.
    enum Settings {
        static let checkInNudgesToggle = "settings.checkInNudgesToggle"
        static let rhythmPicker = "settings.rhythmPicker"
        static let supplementAlertsToggle = "settings.supplementAlertsToggle"
        static let quietSuggestPicker = "settings.quietSuggestPicker"
        static let icloudBackupToggle = "settings.icloudBackupToggle"
        static let mirrorEnabledToggle = "settings.mirrorEnabledToggle"
        static let folderPicker = "settings.folderPicker"
        static let fileNamingPicker = "settings.fileNamingPicker"
        static let exportZip = "settings.exportZip"
        static let folderPickFailedOK = "settings.folderPickFailedOK"
        static let zipExportFailedOK = "settings.zipExportFailedOK"
    }
}
