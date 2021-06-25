# Turbo-iOS-Base
### Turbo-iOS base project that's entirely driven from your backend Rails app.

There were _five main goals_ for this project:
1. reusable base project that can be pointed to any Rails app
2. app styling, tabs and navbar buttons driven from the server
3. handle both authenticated and unauthenticated users
4. all logic and functionality contained in a single Swift file
5. no need for other developers to write any Swift code

_Disclaimer_: It's been over six years since I've written anything in Objective-C, and I've never written any Swift prior to this, so the code has lots of room for improvement, refactoring, cleanup, etc.

If you haven't already, I _highly recommend_ you read the following articles about [Turbo-iOS](https://github.com/hotwired/turbo-ios).
- [Hybrid iOS apps with Turbo by Joe Masilotti](https://masilotti.com/turbo-ios/hybrid-apps-with-turbo/)
- [Drifting Ruby Turbo Native for iOS by David Kimura](https://www.driftingruby.com/episodes/turbo-native-for-ios)
- [Native tab bar with Turbo-iOS by Bram Jetten](https://bramjetten.dev/articles/native-tab-bar-with-turbo-ios)

#### Clone Repo
Clone this repo locally to get started.
```
git clone https://github.com/dalezak/turbo-ios-base.git
```

#### Update Target Information
- open **App.xcodeproj**
- click on **App** project
- select **App** under **Targets**
- change **Display Name** to the name of your app
- change **Bundle Identifier** to your reverse domain name

#### Update Info.plist URLs
- open **Info.plist** file
- expand **TURBO_URL** item
- change **development** to your local environment
- change **production** to your production environment

#### Replace Asset Images
- visit **https://appicon.co**
- upload **1024 x 1024** image
- click **Generate** button
- replace **Assets.xcassets** in the project with downloaded file

#### Add Turbo Gem
Add `turbo-rails` to your **Gemfile**.
```
gem "turbo-rails"
```

#### Import Turbo Javascript
Add the following code to your **application.js** file.
```
import { Turbo } from "@hotwired/turbo-rails";
window.Turbo = Turbo;
```
Add any custom javascript to **turbo/bridge.js** in your javascript folder.
```
export default class Bridge {
  static sayHello() {
    document.body.innerHTML = "<h1>Hello!</h1>"
  }
}
```
Then import this in your **application.js** file.
```
import Bridge from "../turbo/bridge.js";
window.bridge = Bridge;
```

#### Add Rails Helpers
In your Rails app, add the following helpers to your `application_helper.rb`
```
def turbo?
  request.user_agent.include?("Turbo-")
end

def turbo_ios?
  request.user_agent.include?("Turbo-iOS")
end

def turbo_android?
  request.user_agent.include?("Turbo-Android")
end
```

#### Add Authenticated Header
Add the following **metatag** to your `<head>` so the app knows if a user is logged in or not.
```
<meta name="turbo:authenticated" content="<%= user_signed_in? %>">
```

#### Hide Page Navigation
Since Turbo-iOS handles the native navbar, you don't need to show your page navigation anymore. 
Add `unless turbo?` check around where you usually render your navbar in your Rails app. 
```
<% unless turbo? %>
  <nav class="d-block">
    <%= render 'partials/navbar' %>
  </nav>
<% end %>
```

#### Add Turbo Controller
Add **turbo_controller.rb** which will return `turbo.json` used for rules and settings, here's a sample to get you started.
```
class TurboController < ApplicationController
  def index
    render json: {
      "settings": {
        "navbar": {
          "background": "#888888",
          "foreground": "#ffffff"
        },
        "tabbar": {
          "background": "#888888",
          "selected": "#ffffff",
          "unselected": "#bbbbbb"
        },
        "tabs": [
          {
            "title": "Home",
            "visit": "/",
            "icon_ios": "house",
            "protected": false
          },
          {
            "title": "Profile",
            "visit": "/profile",
            "icon_ios": "building.2",
            "protected": true
          }
        ],
        "buttons": [
          {
            "path": "/",
            "side": "left",
            "icon_ios": "line.horizontal.3",
            "script": "window.bridge.showMenu();",
            "protected": false
          },
          {
            "path": "/",
            "side": "right",
            "title": "Add",
            "visit": "/posts/new",
            "protected": true
          }
        ]
      },
      "rules": [
        {
          "patterns": [
            "/new$",
            "/edit$"
          ],
          "properties": {
            "presentation": "modal"
          }
        },
        {
          "patterns": [
            "/users/login"
          ],
          "properties": {
            "presentation": "modal"
          }
        },
        {
          "patterns": [
            "/users/logout"
          ],
          "properties": {
            "presentation": "replace"
          }
        }
      ]
    }
    end 
end
```
To see all the available iOS icons you can use for navbar buttons or tabbar icons, visit [https://hotpot.ai/free-icons?s=sfSymbols](https://hotpot.ai/free-icons?s=sfSymbols).

#### Add Turbo Route
In your **routes.rb** add route pointing to `turbo#index`.
```
get 'turbo', to: "turbo#index", as: :turbo
```

#### Write Beautiful Ruby
_That's it!_ Everything should now be configured including the app colors, tabs, navbar buttons, etc which are all driven from the `turbo.json` returned from `turbo_controller.rb`. 

Now the app tabs and navbar buttons should appear according to the `protected` property if the user is authenticated or not. Your navbar buttons can either visit a page or trigger javascript on your server.

The best part is you shouldn't need to write any Swift code, so you can focus on your backend Rails application. This is something I've dreamt about ever since I first started using Rails, and it's now possible thanks to [Turbo-iOS](https://github.com/hotwired/turbo-ios)!

If you find this project useful or have suggestions on improvements, _please let me know!_
