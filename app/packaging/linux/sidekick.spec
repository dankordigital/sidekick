# Built from an already-made root (package.sh passes _sidekick_root).
Name:           sidekick
Version:        @VERSION@
Release:        1
Summary:        Use your phone and computer as one
License:        Proprietary
URL:            https://getsidekick.app
AutoReqProv:    no
Requires:       gtk3, libsecret
Recommends:     (libayatana-appindicator-gtk3 or libappindicator-gtk3), xdotool, libnotify

%description
Send files both ways, control one device from another, and connect
without shared Wi-Fi. Everything is encrypted.

%install
mkdir -p %{buildroot}
cp -a %{_sidekick_root}/. %{buildroot}/

%files
/opt/sidekick
/usr/bin/sidekick
/usr/share/applications/dev.sidekick.sidekick.desktop
/usr/share/icons/hicolor/512x512/apps/dev.sidekick.sidekick.png
