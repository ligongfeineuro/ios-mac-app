//
//  DependencyContainer.swift
//  ProtonVPN - Created on 21/08/2019.
//
//  Copyright (c) 2019 Proton Technologies AG
//
//  This file is part of ProtonVPN.
//
//  ProtonVPN is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  ProtonVPN is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with ProtonVPN.  If not, see <https://www.gnu.org/licenses/>.
//

import AppKit
import Foundation
import vpncore
import BugReport
import NetworkExtension

final class DependencyContainer: Container {
    // Singletons
    private lazy var navigationService = NavigationService(self)

    private lazy var windowService: WindowService = WindowServiceImplementation(factory: self)
    private lazy var wireguardFactory = WireguardMacProtocolFactory(bundleId: config.wireguardVpnExtensionBundleIdentifier,
                                                                    appGroup: config.appGroup,
                                                                    factory: self)
    private lazy var openVpnFactory = OpenVpnMacProtocolFactory(bundleId: config.openVpnExtensionBundleIdentifier,
                                                                appGroup: config.appGroup,
                                                                factory: self)
    private lazy var vpnAuthentication: VpnAuthentication = {
        return VpnAuthenticationManager(self)
    }()

    private lazy var appSessionManager: AppSessionManagerImplementation = AppSessionManagerImplementation(factory: self)
    private lazy var macAlertService: MacAlertService = MacAlertService(factory: self)

    private lazy var xpcConnectionsRepository: XPCConnectionsRepository = XPCConnectionsRepositoryImplementation()

    // Refreshes app data at predefined time intervals
    private lazy var refreshTimer = AppSessionRefreshTimer(factory: self,
                                                           refreshIntervals: (AppConstants.Time.fullServerRefresh,
                                                                              AppConstants.Time.serverLoadsRefresh,
                                                                              AppConstants.Time.userAccountRefresh),
                                                           canRefreshLoads: { return NSApp.isActive })

    // Manages app updates
    private lazy var updateManager = UpdateManager(self)

    private lazy var appCertificateRefreshManager = AppCertificateRefreshManager(appSessionManager: makeAppSessionManager(), vpnAuthenticationStorage: makeVpnAuthenticationStorage())

    private lazy var networkingDelegate: NetworkingDelegate = macOSNetworkingDelegate(alertService: macAlertService) // swiftlint:disable:this weak_delegate

    private lazy var planService = CorePlanService(networking: makeNetworking())
    private lazy var doh: DoHVPN = {
        let propertiesManager = makePropertiesManager()
        let doh = DoHVPN(alternativeRouting: propertiesManager.alternativeRouting,
                         customHost: propertiesManager.apiEndpoint)
        propertiesManager.onAlternativeRoutingChange = { alternativeRouting in
            doh.alternativeRouting = alternativeRouting
        }
        return doh
    }()
    private lazy var sysexManager = SystemExtensionManager(factory: self)

    public init() {
        let prefix = Bundle.main.infoDictionary!["AppIdentifierPrefix"] as! String

        super.init(Config(os: "MacOS",
                          appIdentifierPrefix: prefix,
                          appGroup: "\(prefix)group.ch.protonvpn.mac",
                          accessGroup: "\(prefix)ch.protonvpn.macos",
                          openVpnExtensionBundleIdentifier: "ch.protonvpn.mac.OpenVPN-Extension",
                          wireguardVpnExtensionBundleIdentifier: "ch.protonvpn.mac.WireGuard-Extension"))
    }

    // MARK: - Overridden config methods
    override var modelId: String? {
        makeModelIdChecker().modelId
    }

    override var vpnConnectionInterceptPolicies: [VpnConnectionInterceptPolicyItem] {
        ConnectionIntercepts(factory: self).intercepts
    }

    // MARK: - Overridden factory methods
    // MARK: DoHVPNFactory
    override func makeDoHVPN() -> DoHVPN {
        doh
    }

    // MARK: NetworkingDelegate
    override func makeNetworkingDelegate() -> NetworkingDelegate {
        networkingDelegate
    }

    // MARK: CoreAlertServiceFactory
    override func makeCoreAlertService() -> CoreAlertService {
        macAlertService
    }

    // MARK: OpenVPNProtocolFactoryCreator
    override func makeOpenVpnProtocolFactory() -> OpenVpnProtocolFactory {
        openVpnFactory
    }

    // MARK: WireguardProtocolFactoryCreator
    override func makeWireguardProtocolFactory() -> WireguardProtocolFactory {
        wireguardFactory
    }

    // MARK: VpnCredentialsConfiguratorFactoryCreator
    override func makeVpnCredentialsConfiguratorFactory() -> VpnCredentialsConfiguratorFactory {
        MacVpnCredentialsConfiguratorFactory(propertiesManager: makePropertiesManager())
    }

    // MARK: VpnAuthentication
    override func makeVpnAuthentication() -> VpnAuthentication {
        vpnAuthentication
    }

    // MARK: LogContentProviderFactory
    override func makeLogContentProvider() -> LogContentProvider {
        let appLogsFolder = makeLogFileManager()
            .getFileUrl(named: AppConstants.Filenames.appLogFilename)
            .deletingLastPathComponent()
        return MacOSLogContentProvider(appLogsFolder: appLogsFolder,
                                       wireguardProtocolFactory: makeWireguardProtocolFactory(),
                                       openVpnProtocolFactory: makeOpenVpnProtocolFactory())
    }

    // MARK: UpdateManagerFactory
    override func makeUpdateChecker() -> UpdateChecker {
        updateManager
    }
}

extension DoHVPN {
    convenience init(alternativeRouting: Bool, customHost: String?) {
        #if !RELEASE
        let atlasSecret: String? = ObfuscatedConstants.atlasSecret
        #else
        let atlasSecret: String? = nil
        #endif

        self.init(apiHost: ObfuscatedConstants.apiHost,
                  verifyHost: ObfuscatedConstants.humanVerificationV3Host,
                  alternativeRouting: alternativeRouting,
                  customHost: customHost,
                  atlasSecret: atlasSecret,
                  // Will get updated once AppStateManager is initialized
                  appState: .disconnected)
    }
}

// MARK: PlanServiceFactory
extension DependencyContainer: PlanServiceFactory {
    func makePlanService() -> PlanService {
        return planService
    }
}

// MARK: NavigationServiceFactory
extension DependencyContainer: NavigationServiceFactory {
    func makeNavigationService() -> NavigationService {
        return navigationService
    }
}

// MARK: WindowServiceFactory
extension DependencyContainer: WindowServiceFactory {
    func makeWindowService() -> WindowService {
        return windowService
    }
}

// MARK: OsxUiAlertServiceFactory
extension DependencyContainer: UIAlertServiceFactory {
    func makeUIAlertService() -> UIAlertService {
        return OsxUiAlertService(factory: self)
    }
}

// MARK: AppSessionManagerFactory
extension DependencyContainer: AppSessionManagerFactory {
    func makeAppSessionManager() -> AppSessionManager {
        return appSessionManager
    }
}

// MARK: NotificationManagerFactory
extension DependencyContainer: NotificationManagerFactory {
    func makeNotificationManager() -> NotificationManagerProtocol {
        return NotificationManager(appStateManager: makeAppStateManager(),
                                   appSessionManager: makeAppSessionManager())
    }
}

// MARK: MigrationManagerFactory
extension DependencyContainer: MigrationManagerFactory {
    func makeMigrationManager() -> MigrationManagerProtocol {
        let propertiesManager = makePropertiesManager()
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        return MigrationManager(propertiesManager, currentAppVersion: currentVersion)
    }
}

// MARK: RefreshTimerFactory
extension DependencyContainer: AppSessionRefreshTimerFactory {
    func makeAppSessionRefreshTimer() -> AppSessionRefreshTimer {
        return refreshTimer
    }
}

// MARK: - AppSessionRefresherFactory
extension DependencyContainer: AppSessionRefresherFactory {
    func makeAppSessionRefresher() -> AppSessionRefresher {
        return appSessionManager
    }
}

// MARK: - HeaderViewModelFactory
extension DependencyContainer: HeaderViewModelFactory {
    func makeHeaderViewModel() -> HeaderViewModel {
        return HeaderViewModel(factory: self, appStateManager: makeAppStateManager(), navService: navigationService)
    }
}

// MARK: - UpdateFileSelectorFactory
extension DependencyContainer: UpdateFileSelectorFactory {
    func makeUpdateFileSelector() -> UpdateFileSelector {
        return UpdateFileSelectorImplementation(self)
    }
}

// MARK: - SystemExtensionManagerFactory
extension DependencyContainer: SystemExtensionManagerFactory {
    func makeSystemExtensionManager() -> SystemExtensionManager {
        return sysexManager
    }
}

// MARK: XPCConnectionsRepositoryFactory
extension DependencyContainer: XPCConnectionsRepositoryFactory {
    func makeXPCConnectionsRepository() -> XPCConnectionsRepository {
        return xpcConnectionsRepository
    }
}

// MARK: BugReportCreatorFactory
extension DependencyContainer: BugReportCreatorFactory {
    func makeBugReportCreator() -> BugReportCreator {
        return MacOSBugReportCreator()
    }
}

// MARK: AppCertificateRefreshManagerFactory
extension DependencyContainer: AppCertificateRefreshManagerFactory {
    func makeAppCertificateRefreshManager() -> AppCertificateRefreshManager {
        return appCertificateRefreshManager
    }
}

// MARK: ModelIdCheckerFactory
extension DependencyContainer: ModelIdCheckerFactory {
    func makeModelIdChecker() -> ModelIdCheckerProtocol {
        return ModelIdChecker()
    }
}

// MARK: ProtonReachabilityCheckerFactory
extension DependencyContainer: ProtonReachabilityCheckerFactory {
    func makeProtonReachabilityChecker() -> ProtonReachabilityChecker {
        return URLSessionProtonReachabilityChecker()
    }
}

// MARK: CouponViewModelFactory
extension DependencyContainer: CouponViewModelFactory {
    func makeCouponViewModel() -> CouponViewModel {
        return CouponViewModel(paymentsApiService: makePaymentsApiService(), appSessionRefresher: appSessionManager)
    }
}

// MARK: StatusMenuViewModelFactory
extension DependencyContainer: StatusMenuViewModelFactory {
    func makeStatusMenuViewModel() -> StatusMenuViewModel {
        return StatusMenuViewModel(factory: self)
    }
}

// MARK: UpdateManagerFactory
extension DependencyContainer: UpdateManagerFactory {
    func makeUpdateManager() -> UpdateManager {
        return updateManager
    }
}
