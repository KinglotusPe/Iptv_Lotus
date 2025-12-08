import os

def patch_manifest():
    manifest_path = "android/app/src/main/AndroidManifest.xml"
    
    if not os.path.exists(manifest_path):
        print(f"Error: Manifest not found at {manifest_path}")
        exit(1)

    with open(manifest_path, "r") as f:
        content = f.read()

    print("Original Manifest content read.")

    # 1. Add Internet Permission if missing
    permission = '<uses-permission android:name="android.permission.INTERNET"/>'
    if permission not in content:
        content = content.replace('<application', f'{permission}\n    <application')
        print("Injected INTERNET permission.")

    # 2. Add Cleartext Traffic (HTTP support)
    if 'android:usesCleartextTraffic="true"' not in content:
        content = content.replace('<application', '<application android:usesCleartextTraffic="true"')
        print("Injected Cleartext Traffic support.")

    with open(manifest_path, "w") as f:
        f.write(content)
        
    print("Manifest patched successfully.")

if __name__ == "__main__":
    patch_manifest()
