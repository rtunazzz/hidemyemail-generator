<p align="center"><img width=60% src="docs/header.png"></p>

> Automated generation of Apple's iCloud emails via HideMyEmail.

_You do need to have an active iCloud+ subscription to be able to generate iCloud emails..._

<p align="center"><img src="docs/example.png"></p>

## Usage

You can get prebuild binaries for Windows & ARM Macs from the [releases page](https://github.com/rtunazzz/hidemyemail-generator/releases). Follow the guide steps 1 & 2 below if you'd like to run it from source, otherwise you can skip to the 3rd step - set your cookie and run.

Apple allows you to create 5 * # of people in your iCloud familly emails every 30 mins or so. From my experience, they cap the amount of iCloud emails you can generate at ~700.

## Setup
> Python 3.9+ is required!

1. Clone this repository

```bash
git clone https://github.com/rtunazzz/hidemyemail-generator
```

2. Install requirements

```bash
pip install -r requirements.txt
```

3. [Save your cookie string](https://github.com/rtunazzz/hidemyemail-generator#getting-icloud-cookie-string)

   > You only need to do this once 🙂

4. You can now run the gen with:


**on Mac:**

```bash
python3 main.py
```

**on Windows:**

```bash
python main.py
```

## Getting iCloud cookie string

> There is more than one way how you can get the required cookie string but this one is _imo_ the simplest...

1. Download [EditThisCookie](https://chrome.google.com/webstore/detail/editthiscookie/fngmhnnpilhplaeedifhccceomclgfbg) Chrome extension

2. Go to [EditThisCookie settings page](chrome-extension://fngmhnnpilhplaeedifhccceomclgfbg/options_pages/user_preferences.html) and set the preferred export format to `Semicolon separated name=value pairs`

<p align="center"><img src="docs/cookie-settings.png" width=70%></p>

3. Navigate to [iCloud settings](https://www.icloud.com/settings/) in your browser and log in

4. Click on the EditThisCookie extension and export cookies

<p align="center"><img src="docs/export-cookies.png" width=70%></p>

5. Paste the exported cookies into a file named `cookie.txt`

# License

Licensed under the MIT License - see the [LICENSE file](./LICENSE) for more details.

Made by **[rtuna](https://twitter.com/rtunazzz)**.
