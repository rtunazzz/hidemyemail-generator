<p align="center"><img width=60% src="docs/header.png"></p>

> Automated generation of Apple's iCloud emails via HideMyEmail.

_You do need to have an active iCloud+ subscription to be able to generate iCloud emails..._

<p align="center"><img src="docs/example.png"></p>

## Usage

You can get prebuild binaries for Windows & ARM Macs from the [releases page](https://github.com/rtunazzz/hidemyemail-generator/releases). Follow the guide steps 1 & 2 below if you'd like to run it from source, otherwise you can skip to the 3rd step - set your cookie and run.

Apple allows you to create 5 * # of people in your iCloud familly emails every 30 mins or so. From my experience, they cap the amount of iCloud emails you can generate at ~700.

## Setup
> Python 3.12+ is required. [uv](https://docs.astral.sh/uv/) is recommended.

1. Clone this repository

```bash
git clone https://github.com/rtunazzz/hidemyemail-generator
cd hidemyemail-generator
```

2. Install dependencies and create a virtual environment

```bash
uv sync
```

3. [Save your cookie string](https://github.com/rtunazzz/hidemyemail-generator#getting-icloud-cookie-string)

   > You only need to do this once 🙂

4. Run the CLI

```bash
uv run hidemyemail generate --label test --count 1
```

## Getting iCloud cookie string

> There is more than one way how you can get the required cookie string but this one is _imo_ the simplest...

1. Download [Cookie Editor](https://cookie-editor.com/) Chrome/Firefox extension

2. Navigate to [iCloud settings](https://www.icloud.com/settings/) in your browser and log in

3. Open the Cookie Editor extension and click "Export" on the bottom and then "Header String".

4. Paste the exported cookies into a file named `icloud_cookies.txt`

# License

Licensed under the MIT License - see the [LICENSE file](./LICENSE) for more details.

Made by **[rtuna](https://twitter.com/rtunazzz)**.
