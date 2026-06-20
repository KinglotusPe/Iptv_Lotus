import os
import shutil

def patch_signing():
    gradle_path = "android/app/build.gradle"
    keystore_src = "scripts/key.jks"
    keystore_dst = "android/app/key.jks"

    if not os.path.exists(gradle_path):
        print(f"Error: Gradle file not found at {gradle_path}")
        exit(1)

    # 1. Copy keystore file
    if os.path.exists(keystore_src):
        shutil.copy(keystore_src, keystore_dst)
        print("Copied key.jks to android/app/")
    else:
        print(f"Error: Source keystore not found at {keystore_src}")
        exit(1)

    # 2. Read build.gradle
    with open(gradle_path, "r", encoding="utf-8") as f:
        content = f.read()

    # 3. Define signing configuration block
    signing_config = """
    signingConfigs {
        release {
            storeFile file('key.jks')
            storePassword System.getenv("LOTUSPLAY_KEYSTORE_PASSWORD") ?: 'lotusplay123'
            keyAlias System.getenv("LOTUSPLAY_KEY_ALIAS") ?: 'lotusplay'
            keyPassword System.getenv("LOTUSPLAY_KEY_PASSWORD") ?: 'lotusplay123'
        }
    }
"""

    # Inject signingConfigs block inside android {
    android_index = content.find("android {")
    if android_index != -1:
        # Find the first opening brace index of the android block
        brace_index = content.find("{", android_index)
        if brace_index != -1:
            content = content[:brace_index + 1] + signing_config + content[brace_index + 1:]
            print("Injected signingConfigs block.")
        else:
            print("Error: Could not find android opening brace.")
            exit(1)
    else:
        print("Error: Could not find 'android {' in build.gradle.")
        exit(1)

    # 4. Update release build type to use the new release signingConfig
    # Match both 'signingConfig signingConfigs.debug' and 'signingConfig = signingConfigs.debug'
    modified = False
    
    if "signingConfig signingConfigs.debug" in content:
        content = content.replace("signingConfig signingConfigs.debug", "signingConfig signingConfigs.release")
        modified = True
    elif "signingConfig = signingConfigs.debug" in content:
        content = content.replace("signingConfig = signingConfigs.debug", "signingConfig = signingConfigs.release")
        modified = True
        
    # As fallback, if release block exists but no signingConfig is specified, we inject it inside release { ... }
    if not modified:
        release_index = content.find("release {")
        if release_index != -1:
            brace_index = content.find("{", release_index)
            if brace_index != -1:
                content = content[:brace_index + 1] + "\n            signingConfig signingConfigs.release" + content[brace_index + 1:]
                print("Injected signingConfig release inside release block.")
                modified = True

    if modified:
        with open(gradle_path, "w", encoding="utf-8") as f:
            f.write(content)
        print("build.gradle patched successfully for release signing.")
    else:
        print("Warning: Could not configure release signingConfig in build.gradle.")

if __name__ == "__main__":
    patch_signing()
