import UIKit
import Turbo
import WebKit
import SwiftUI
import SafariServices

class TurboController: UINavigationController {

    private lazy var tabBar = makeTabBar()
    private lazy var session = makeSession()
    private lazy var modalSession = makeSession()
    private lazy var settings = loadSettings()
    private lazy var processPool = WKProcessPool()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadNavBar()
        loadTabBar()
        loadTabs()
        loadHome()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        tabBar.invalidateIntrinsicContentSize()
    }
    
    func visit(url: URL, action: VisitAction = .advance, properties: PathProperties = [:]) {
        if (presentedViewController != nil) {
            dismiss(animated: true)
        }
        let viewController = VisitableViewController(url: url)
        if url.path == "/", !viewControllers.isEmpty {
            popViewController(animated: true)
            viewControllers = Array() + [viewController]
            session.visit(viewController)
        } else if isModal(properties) {
            present(viewController, animated: true)
            modalSession.visit(viewController)
        } else if isReplace(properties) {
            viewControllers = Array(viewControllers.dropLast()) + [viewController]
            session.visit(viewController)
            session.reload()
        } else if session.activeVisitable?.visitableURL == url {
            let viewControllers = viewControllers.dropLast()
            setViewControllers(viewControllers + [viewController], animated: false)
            session.visit(viewController)
        } else if action == .advance {
            pushViewController(viewController, animated: true)
            session.visit(viewController)
        } else if action == .replace {
            viewControllers = Array() + [viewController]
            session.visit(viewController)
        } else if action == .restore {
            popViewController(animated: true)
            session.visit(viewController)
        } else {
            pushViewController(viewController, animated: true)
            session.visit(viewController)
        }
    }
    
    func loadHome() {
        let url = turboUrl()
        let properties = pathProperties(url)
        visit(url: url, action: .replace, properties: properties)
    }
    
    func loadNavBar() {
        if let navbar = settings["navbar"] as? Dictionary<String, String> {
            navigationBar.tintColor = UIColor(hexRGB: navbar["foreground"])
            navigationBar.barTintColor = UIColor(hexRGB: navbar["background"])
            navigationBar.titleTextAttributes = [.foregroundColor: UIColor(hexRGB: navbar["foreground"]) as Any]
        }
    }
    
    func loadTabBar() {
        if let tabbar = settings["tabbar"] as? Dictionary<String, String> {
            UITabBar.appearance().barTintColor = UIColor(hexRGB: tabbar["background"])
            UITabBar.appearance().tintColor = UIColor(hexRGB: tabbar["selected"])
            UITabBar.appearance().unselectedItemTintColor = UIColor(hexRGB: tabbar["unselected"])
        }
    }
    
    func loadTabs(_ authenticated: Bool = false) {
        tabBar.items?.removeAll()
        if let tabs = settings["tabs"] as? [Dictionary<String, AnyObject>] {
            for (index, tab) in tabs.enumerated() {
                let title = tab["title"] as? String
                let image = tab["icon_ios"] as? String
                let protected = tab["protected"] as? Bool ?? false
                let tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: image!), tag: index)
                if ((protected && authenticated) || protected == false) {
                    tabBar.items?.append(tabBarItem)
                }
            }
            if (tabBar.items!.count > 0) {
                tabBar.selectedItem = tabBar.items![0]
            }
        }
        if (tabBar.items!.count > 0) {
            tabBar.frame = CGRect(x: 0, y: self.view.frame.height - self.view.safeAreaInsets.bottom + 49.0, width: self.view.frame.width, height: 49)
            tabBar.isHidden = false
            tabBar.layer.zPosition = 0
        }
        else {
            tabBar.frame = CGRect(x: 0, y: self.view.frame.height, width: self.view.frame.width, height: 0)
            tabBar.isHidden = true
            tabBar.layer.zPosition = -1
        }
    }
    
    func loadButtons(_ authenticated: Bool = false) {
        if let buttons = settings["buttons"] as? [Dictionary<String, AnyObject>] {
            let viewController = session.topmostVisitable!.visitableViewController
            var leftBarButtonItems: [UIBarButtonItem] = []
            var rightBarButtonItems: [UIBarButtonItem] = []
            for (_, button) in buttons.enumerated() {
                let path: String? = button["path"] as? String
                if (path == session.webView.url?.path) {
                    let title: String? = button["title"] as? String
                    let icon: String? = button["icon_ios"] as? String
                    let side: String? = button["side"] as? String
                    let visit: String? = button["visit"] as? String
                    let script: String? = button["script"] as? String
                    let protected = button["protected"] as? Bool ?? false
                    if ((protected && authenticated) || protected == false) {
                        let button: UIBarButtonItem? = loadButton(title: title, icon: icon)
                        if (button != nil) {
                            button!.actionClosure = {
                                if (visit != nil) {
                                    let url = self.turboUrl(visit)
                                    let properties = self.pathProperties(url)
                                    self.visit(url: url, action: .replace, properties: properties)
                                }
                                else if (script != nil) {
                                    self.session.webView.evaluateJavaScript(script!) { _, _ in }
                                }
                            }
                            if (side == "left"){
                                leftBarButtonItems.append(button!)
                            }
                            else if (side == "right") {
                                rightBarButtonItems.append(button!)
                            }
                        }
                    }
                }
            }
            viewController.navigationItem.leftBarButtonItems = leftBarButtonItems
            viewController.navigationItem.rightBarButtonItems = rightBarButtonItems
        }
    }
    
    func loadButton(title: String?, icon: String?) -> UIBarButtonItem? {
        if (title != nil) {
            return UIBarButtonItem(title: title!, style: .plain, target: nil, action: nil)
        }
        else if (icon != nil) {
            let image = UIImage(systemName: icon!)
            return UIBarButtonItem(image: image, style: .plain, target: nil, action: nil)
        }
        return nil;
    }
    
    func loadSettings() -> Dictionary<String, AnyObject> {
        let url = turboUrl("/turbo.json")
        let text: String = URLSession.shared.fetchData(url)
        if let json = stringToDictionary(text: text) {
            return (json["settings"] as? Dictionary<String, AnyObject>)!
        }
        return [:]
    }
    
    func makeTabBar() -> UITabBar {
        let tabBar = UITabBar()
        tabBar.delegate = self
        tabBar.frame = CGRect(x: 0, y: self.view.frame.height, width: self.view.frame.width, height: 0)
        tabBar.items = []
        self.view.addSubview(tabBar)
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        tabBar.leftAnchor.constraint(equalTo: self.view.leftAnchor).isActive = true
        tabBar.rightAnchor.constraint(equalTo: self.view.rightAnchor).isActive = true
        tabBar.bottomAnchor.constraint(equalTo: self.view.bottomAnchor).isActive = true
        return tabBar
    }
    
    func makeSession() -> Session {
        let configuration = WKWebViewConfiguration()
        configuration.processPool = processPool
        configuration.applicationNameForUserAgent = "Turbo-iOS"
        let session = Session(webViewConfiguration: configuration)
        session.delegate = self
        session.webView.allowsLinkPreview = false
        session.pathConfiguration = pathConfiguration
        return session
    }
    
    private lazy var pathConfiguration = PathConfiguration(sources: [
        .server(turboUrl("/turbo.json")),
        .file(Bundle.main.url(forResource: "Turbo", withExtension: "json")!)
    ])
    
    func isModal(_ properties: PathProperties) -> Bool {
        let presentation = properties["presentation"] as? String
        return presentation == "modal"
    }
    
    func isReplace(_ properties: PathProperties) -> Bool {
        let action = properties["action"] as? String
        return action == "replace"
    }
    
    func isRestore(_ properties: PathProperties) -> Bool {
        let action = properties["action"] as? String
        return action == "restore"
    }
    
    func pathProperties(_ url: URL) -> PathProperties {
        return pathConfiguration.properties(for: url)
    }
    
    func turboPath(_ path: String? = "") -> String {
        let environment = ProcessInfo.processInfo.environment["ENVIRONMENT"]! as String
        let backendURL = Bundle.main.infoDictionary?["TURBO_URL" as String] as! Dictionary<String, String>
        return backendURL[environment]! + path!;
    }
    
    func turboUrl(_ path: String? = "") -> URL {
        return URL(string: turboPath(path))!
    }
    
    func stringToDictionary(text: String) -> [String: Any]? {
        if let data = text.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            }
            catch {
                print(error.localizedDescription)
            }
        }
        return nil
    }
    
    func showAlert(title: String, error: Error) {
        let alert = UIAlertController(title: title, message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true)
    }
    
    func showError(title: String, error: Error, image: String = "exclamationmark.triangle") {
        guard let topViewController = self.topViewController else { return }
        topViewController.title = self.appName()
        if let navbar = pathConfiguration.settings["navbar"] as? Dictionary<String, String> {
            topViewController.navigationController?.navigationBar.tintColor = UIColor(hexRGB: navbar["foreground"])
            topViewController.navigationController?.navigationBar.barTintColor = UIColor(hexRGB: navbar["background"])
            topViewController.navigationController?.navigationBar.titleTextAttributes = [.foregroundColor: UIColor(hexRGB: navbar["foreground"]) as Any]
        }
        let errorView = ErrorView(title: title, error: error.localizedDescription, image: image)
        let hostingController = UIHostingController(rootView: errorView)
        topViewController.addChild(hostingController)
        hostingController.view.frame = topViewController.view.frame
        topViewController.view.addSubview(hostingController.view)
        hostingController.didMove(toParent: topViewController)
    }
    
    func appName() -> String {
        return Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String
    }
}

extension TurboController : UITabBarDelegate {
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        let tabs = settings["tabs"] as? [Dictionary<String, AnyObject>]
        let tab = tabs![item.tag] as Dictionary<String, AnyObject>
        let path = tab["visit"] as? String
        let url = turboUrl(path)
        let properties = pathProperties(url)
        visit(url: url, action: .replace, properties: properties)
    }
}

extension TurboController: SessionDelegate {
    func session(_ session: Session, didProposeVisit proposal: VisitProposal) {
        visit(url: proposal.url, action: proposal.options.action, properties: proposal.properties)
    }
    
    func session(_ session: Session, openExternalURL url: URL) {
        let safariViewController = SFSafariViewController(url: url)
        present(safariViewController, animated: true, completion: nil)
    }
    
    func session(_ session: Session, didFailRequestForVisitable visitable: Visitable, error: Error) {
        if let turboError = error as? TurboError {
            switch turboError {
            case .http(let statusCode):
                switch statusCode {
                case 401:
                    showError(title: "Login Required", error: turboError, image: "lock.shield")
                case 404:
                    showError(title: "Page Not Found", error: turboError, image: "questionmark.circle")
                default:
                    showError(title: "Problem Loading Page", error: turboError, image: "exclamationmark.triangle")
                }
            case .networkFailure:
                showError(title: "Network Failure", error: turboError, image: "wifi.slash")
            case .timeoutFailure:
                showError(title: "Request Timeout", error: turboError, image: "clock")
            case .contentTypeMismatch:
                showError(title: "Content Type Mismatch", error: turboError, image: "nosign")
            case .pageLoadFailure:
                showError(title: "Problem Loading Page", error: turboError, image: "xmark.square")
            }
        }
        else {
            showError(title: "Problem Loading Page", error: error, image: "exclamationmark.triangle")
        }
    }
    
    func sessionDidFinishRequest(_ session: Session) {
        let script = "document.querySelector(\"meta[name='turbo:authenticated']\").content"
        session.webView.evaluateJavaScript(script, completionHandler: { (html: Any?, error: Error?) in
            let authenticated = html as? String
            self.loadTabs(authenticated == "true")
            self.loadButtons(authenticated == "true")
        })
    }
}

extension URLSession {
  func fetchData(_ url: URL) -> String {
    var text: String = ""
    let semaphore = DispatchSemaphore(value: 0)
    let task = self.dataTask(with: url) {(data, response, error) in
        if (data != nil) {
            text = String(data: data!, encoding: String.Encoding.utf8)!
        }
        semaphore.signal()
    }
    task.resume()
    semaphore.wait()
    return text;
  }
}

extension WKWebView {
    func evaluate(_ script: String) -> String {
        var response = ""
        var finished = false
        evaluateJavaScript(script, completionHandler: { (result, error) in
            if error == nil && result != nil {
                response = result as! String
            }
            finished = true
        })
        while !finished {
            RunLoop.current.run(mode: RunLoop.Mode(rawValue: "NSDefaultRunLoopMode"), before: NSDate.distantFuture)
        }
        return response;
    }
}

extension UIBarButtonItem {
    private struct AssociatedObject {
        static var key = "action_closure_key"
    }

    var actionClosure: (()->Void)? {
        get {
            return objc_getAssociatedObject(self, &AssociatedObject.key) as? ()->Void
        }
        set {
            objc_setAssociatedObject(self, &AssociatedObject.key, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            target = self
            action = #selector(didTapButton(sender:))
        }
    }

    @objc func didTapButton(sender: Any) {
        actionClosure?()
    }
}

extension UIColor {
    convenience init?(hexRGBA: String?) {
        guard let rgba = hexRGBA, let val = Int(rgba.replacingOccurrences(of: "#", with: ""), radix: 16) else {
            return nil
        }
        self.init(red: CGFloat((val >> 24) & 0xff) / 255.0, green: CGFloat((val >> 16) & 0xff) / 255.0, blue: CGFloat((val >> 8) & 0xff) / 255.0, alpha: CGFloat(val & 0xff) / 255.0)
    }
    
    convenience init?(hexRGB: String?) {
        guard let rgb = hexRGB else {
            return nil
        }
        self.init(hexRGBA: rgb + "ff")
    }
}

struct ErrorView: View {
    let title: String
    let error: String
    let image: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: image).resizable().scaledToFit().foregroundColor(.accentColor).frame(height: 40)
            Text(title).font(.title).padding(.horizontal)
            Text(error).multilineTextAlignment(.center).padding(.horizontal)
        }
    }
}
