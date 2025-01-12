//
//  Created on 03.01.2022.
//
//  Copyright (c) 2022 Proton AG
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

import UIKit
import Onboarding

final class ViewController: UIViewController {
    @IBOutlet private weak var startAButton: UIButton!
    @IBOutlet private weak var vpnSuccessSwitch: UISwitch!
    @IBOutlet private weak var startBButton: UIButton!

    private var coordinator: OnboardingCoordinator!

    override func viewDidLoad() {
        super.viewDidLoad()

        vpnSuccessSwitch.accessibilityIdentifier = "VPNSuccessSwitch"
        startAButton.accessibilityIdentifier = "StartAButton"
        startBButton.accessibilityIdentifier = "StartBButton"
    }

    @IBAction private func startATapped(_ sender: Any) {
        startOnboarding(variant: .A)
    }

    @IBAction private func startBTapped(_ sender: Any) {
        startOnboarding(variant: .B)
    }

    private func startOnboarding(variant: OnboardingVariant) {
        let colors = Colors(background: UIColor(red: 28/255, green: 27/255, blue: 35/255, alpha: 1),
                            text: .white,
                            textAccent: UIColor(red: 138 / 255, green: 110 / 255, blue: 255 / 255, alpha: 1),
                            brand: UIColor(red: 0.427451, green: 0.290196, blue: 1, alpha: 1),
                            weakText: UIColor(red: 0.654902, green: 0.643137, blue: 0.709804, alpha: 1),
                            activeBrandButton: UIColor(red: 133/255, green: 181/255, blue: 121/255, alpha: 1),
                            secondaryBackground: UIColor(red: 41/255, green: 39/255, blue: 50/255, alpha: 1),
                            textInverted: .black,
                            notification: .white,
                            weakInteraction: UIColor(red: 59 / 255, green: 55 / 255, blue: 71 / 255, alpha: 1))
        coordinator = OnboardingCoordinator(configuration: Configuration(variant: variant, colors: colors, constants: Constants(numberOfDevices: 10, numberOfServers: 1300, numberOfFreeServers: 23, numberOfFreeCountries: 3, numberOfCountries: 61)))
coordinator.delegate = self
        let vc = coordinator.start()
        present(vc, animated: true, completion: nil)
    }
}

extension ViewController: OnboardingCoordinatorDelegate {
    func userDidRequestPlanPurchase(completion: @escaping OnboardingPlanPurchaseCompletion) {
        let planPurchaseViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PlanPurchase") as! PlanPurchaseViewController
        planPurchaseViewController.completion = completion

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            completion(.planPurchaseViewControllerReady(planPurchaseViewController))
        }
    }

    func userDidRequestConnection(completion: @escaping OnboardingConnectionRequestCompletion) {
        let succes = vpnSuccessSwitch.isOn

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            if succes {
                completion(Country(name: "United States", flag: UIImage(named: "Flag")!))
            } else {
                completion(nil)
            }
        }
    }

    func onboardingCoordinatorDidFinish(requiresConnection: Bool) {
        coordinator = nil
        dismiss(animated: true, completion: nil)
    }
}
