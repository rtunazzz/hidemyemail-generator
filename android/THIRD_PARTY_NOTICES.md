# Third-Party Notices / 第三方组件声明

The Android client is covered by the root repository's [MIT License](../LICENSE).
The following components remain subject to their own license terms. This list
reflects the dependencies declared by the Android Gradle build.

Android 客户端适用根目录的 [MIT License](../LICENSE)。以下组件仍受各自许可证
约束；此列表对应 Android Gradle 构建中声明的依赖。

| Component | Declared license | Source |
| --- | --- | --- |
| Android Gradle Plugin | Apache-2.0 | <https://developer.android.com/build/releases/gradle-plugin> |
| Kotlin and Kotlin Coroutines | Apache-2.0 | <https://kotlinlang.org/> |
| AndroidX Activity, Compose, Lifecycle, and Material components | Apache-2.0 | <https://developer.android.com/jetpack/androidx/releases> |
| OkHttp | Apache-2.0 | <https://github.com/square/okhttp> |
| JUnit 4 | EPL-1.0 | <https://github.com/junit-team/junit4> |
| Hamcrest Core (transitive test dependency) | BSD-3-Clause | <https://github.com/hamcrest/JavaHamcrest> |

License texts and notices for packaged transitive dependencies are available
from their respective upstream projects and Maven/Gradle metadata. This file
does not alter any third-party license.

打包的传递依赖许可证文本与声明可从各自上游项目及 Maven/Gradle 元数据取得；本
文件不改变任何第三方许可证。

## Apple interface asset

`app/src/main/res/drawable/ic_hidemyemail_official.png` is the public Hide My
Email icon served by iCloud.com and is used only as the Android launcher icon.
Apple and iCloud are trademarks of Apple Inc.; this asset is not covered by the
repository's MIT license.
