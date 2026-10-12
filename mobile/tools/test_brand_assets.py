"""Static Android branding checks usable without Flutter or Android SDK.

Run: python -m unittest discover -s mobile/tools -p 'test_*.py'
"""
from pathlib import Path
import re
import struct
import unicodedata
import unittest
import wave
import xml.etree.ElementTree as ET

RES = Path(__file__).resolve().parents[1] / "android/app/src/main/res"
MAIN = RES.parent
ANDROID = "{http://schemas.android.com/apk/res/android}"


def forbidden_mobile_content(content):
    normalized = unicodedata.normalize("NFKC", content).casefold()
    words = re.search(r"(?<![^\W\d_])(?:licences?|paiement|payer|acheter|achats?|tarifs?|prix|chariow)(?![^\W\d_])", normalized)
    secrets = re.search(
        r"sk[-_]or[-_]|sk_live_|sk_test_|whsec_|sk-proj-|"
        r"-----begin (?:rsa |ec |openssh )?private key-----|"
        r"openrouter_api_key|chariow_api_key|chariow_pulse_secret|studia_access_tokens|"
        r"(?:api[_-]?key|client[_-]?secret)\s*[:=]\s*['\"][^'\"]+",
        normalized,
    )
    return words or secrets


class AndroidBrandAssetsTest(unittest.TestCase):
    def test_academic_vocabulary_and_no_secrets_in_all_dart_sources(self):
        dart_files = list((Path(__file__).resolve().parents[1] / "lib").rglob("*.dart"))
        self.assertTrue(dart_files)
        for path in dart_files:
            with self.subTest(file=str(path)):
                self.assertIsNone(forbidden_mobile_content(path.read_text()),
                                  f"Vocabulaire interdit ou secret potentiel dans {path}")

    def test_vocabulary_and_secret_guard_detects_regressions(self):
        for text in ("Licence", "LICENCES", "paiement", "payer", "acheter", "achat",
                     "tarif", "prix", "Chariow", "/api/licenses/activate Chariow",
                     "sk-or-v1-example", "sk_live_example", "whsec_example",
                     "OPENROUTER_API_KEY", "apiKey = 'example-secret'",
                     "-----BEGIN PRIVATE KEY-----"):
            with self.subTest(text=text):
                self.assertIsNotNone(forbidden_mobile_content(text))
        self.assertIsNone(forbidden_mobile_content("Espace étudiant L2 SIR · Finaliser mon accès"))

    def test_external_portal_is_a_native_browser_intent(self):
        native = (MAIN / "kotlin/com/studentplanning/studia/MainActivity.kt").read_text()
        dart = (Path(__file__).resolve().parents[1] / "lib/services/student_portal.dart").read_text()
        for content in (native, dart):
            self.assertIn("studia/student_portal", content)
        self.assertIn("Intent.ACTION_VIEW", native)
        self.assertIn("Intent.CATEGORY_BROWSABLE", native)
        self.assertIn('uri.scheme != "https"', native)
        self.assertIn("ActivityNotFoundException", native)

    def test_launcher_images_match_android_density_sizes(self):
        for density, size in {"mdpi": 48, "hdpi": 72, "xhdpi": 96,
                              "xxhdpi": 144, "xxxhdpi": 192}.items():
            data = (RES / f"mipmap-{density}/ic_launcher.png").read_bytes()
            self.assertEqual(data[:8], b"\x89PNG\r\n\x1a\n")
            self.assertEqual(struct.unpack(">II", data[16:24]), (size, size))
        for path in ("drawable-nodpi/ic_launcher_foreground.png",
                     "drawable-nodpi/ic_launcher_monochrome.png",
                     "drawable/studia_splash_mark.png"):
            self.assertTrue((RES / path).is_file())
        manifest = ET.parse(MAIN / "AndroidManifest.xml").getroot()
        application = manifest.find("application")
        self.assertIsNotNone(application)
        self.assertEqual(application.get(ANDROID + "icon"), "@mipmap/ic_launcher")

    def test_splash_is_configured_for_legacy_and_android_12(self):
        old = ET.parse(RES / "values/styles.xml")
        new = ET.parse(RES / "values-v31/styles.xml")
        self.assertIn("@drawable/launch_background",
                      [item.text for item in old.iter("item")])
        self.assertIn("@drawable/studia_splash_mark",
                      [item.text for item in new.iter("item")])

    def test_custom_sounds_are_distinct_and_wired_to_versioned_channels(self):
        frames = []
        for name in ("course", "revision"):
            with wave.open(str(RES / f"raw/studia_{name}.wav")) as audio:
                self.assertEqual(audio.getnchannels(), 1)
                self.assertEqual(audio.getsampwidth(), 2)
                self.assertEqual(audio.getframerate(), 44100)
                self.assertLess(audio.getnframes() / audio.getframerate(), 1.1)
                frames.append(audio.readframes(audio.getnframes()))
        self.assertNotEqual(frames[0], frames[1])
        native = (MAIN / "kotlin/com/studentplanning/studia/MainActivity.kt").read_text()
        self.assertIn('"courses_studia_v2"', native)
        self.assertIn('"revisions_studia_v2"', native)
        self.assertIn("R.raw.studia_course", native)
        self.assertIn("R.raw.studia_revision", native)
        self.assertIn("channel.setSound(sound, attributes)", native)
        keep_xml = (RES / "raw/keep.xml").read_text()
        self.assertIn("@raw/studia_course", keep_xml)
        self.assertIn("@raw/studia_revision", keep_xml)

    def test_mobile_uses_build_time_api_base_url_without_hardcoded_endpoints_or_keys(self):
        mobile_root = Path(__file__).resolve().parents[1]
        self.assertFalse((mobile_root / "planning_etudiant").exists())
        planning_api = (mobile_root / "lib/services/planning_api.dart").read_text()
        self.assertIn("String.fromEnvironment('API_BASE_URL')", planning_api)
        for dart_file in (mobile_root / "lib").rglob("*.dart"):
            content = dart_file.read_text()
            for forbidden in (
                "http://192.168",
                "http://10.0.2.2",
                "http://127.0.0.1",
                "http://localhost",
                "openrouter.ai",
                "api.chariow.com",
                "sk-or-",
                "sk_live_",
                "whsec_",
            ):
                self.assertNotIn(forbidden, content.lower(), f"Forbidden literal {forbidden} in {dart_file}")



if __name__ == "__main__":
    unittest.main()
