$env:GRADLE_USER_HOME = 'D:\.gradle'
$env:JAVA_HOME = 'C:\Users\Prasanna\.jdks\jdk-17.0.12+7'
$env:ANDROID_HOME = 'D:\Android\Sdk'
Write-Host "GRADLE_USER_HOME: $env:GRADLE_USER_HOME"
Write-Host "JAVA_HOME: $env:JAVA_HOME"
Write-Host "ANDROID_HOME: $env:ANDROID_HOME"
flutter build apk --debug --android-skip-build-dependency-validation
