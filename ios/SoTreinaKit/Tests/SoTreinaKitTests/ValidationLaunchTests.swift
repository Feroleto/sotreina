import Testing
@testable import SoTreinaKit

@Suite struct ValidationLaunchTests {
    @Test func readsTheThreeVariables() {
        let launch = ValidationLaunch(environment: [
            "SOTREINA_SCREEN": "gymRoutines", "SOTREINA_THEME": "dark", "SOTREINA_LANG": "en", "PATH": "/usr/bin",
        ])
        #expect(launch == ValidationLaunch(destination: .page(.gymRoutines), theme: .dark, lang: .en))
        #expect(launch.tab == .gym)
    }

    @Test func noVariablesOverrideNothing() {
        let launch = ValidationLaunch(environment: ["PATH": "/usr/bin"])
        #expect(launch == ValidationLaunch())
        #expect(launch.tab == nil)
        #expect(!launch.startsSessionMinimized)
    }

    @Test func unknownValuesAreIgnored() {
        let launch = ValidationLaunch(environment: [
            "SOTREINA_SCREEN": "runAnalysis", "SOTREINA_THEME": "sepia", "SOTREINA_LANG": "es",
        ])
        #expect(launch == ValidationLaunch())
    }

    @Test func autoThemeIsNotAnOverride() {
        #expect(ValidationLaunch(environment: ["SOTREINA_THEME": "auto"]).theme == nil)
        #expect(ValidationLaunch(environment: ["SOTREINA_THEME": "light"]).theme == .light)
    }

    @Test func screenNames() {
        #expect(ValidationLaunch.Destination(name: "session") == .session)
        #expect(ValidationLaunch.Destination(name: "sessionMinimized") == .sessionMinimized)
        #expect(ValidationLaunch.Destination(name: "profile") == .tab(.profile))
        #expect(ValidationLaunch.Destination(name: "runActivities") == .page(.runActivities))
        // a tab name lands on the tab; its page has its own name
        #expect(ValidationLaunch.Destination(name: "gym") == .tab(.gym))
    }

    @Test func everyPageBelongsToTheTabThatListsIt() {
        for page in AppPage.allCases {
            #expect(page.tab.pages.contains(page))
        }
    }

    @Test func onlyTheSessionItselfStaysFullScreen() {
        #expect(!ValidationLaunch(destination: .session).startsSessionMinimized)
        #expect(ValidationLaunch(destination: .sessionMinimized).startsSessionMinimized)
        #expect(ValidationLaunch(destination: .page(.runActivities)).startsSessionMinimized)
        #expect(ValidationLaunch(destination: .tab(.profile)).startsSessionMinimized)
    }
}
