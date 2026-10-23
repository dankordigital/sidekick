// The browser preview has no dart:ffi: Windows input is never used there.
import 'input.dart';

class WindowsInputInjector extends UnsupportedInputInjector {}

int? virtualKeyFor(String name) => null;

int get inputStructSize => 40;
