"""Build configuration checks; no Flutter SDK, network or credentials required."""
import unittest

from validate_build_config import validate_api_base_url, validate_build_number


class BuildConfigTest(unittest.TestCase):
    def test_public_https_api_and_proxy_prefix_are_accepted(self):
        for url in ("https://studia-api.onrender.com", "https://api.studia.fr/",
                    "https://api.studia.fr:8443/services/studia"):
            with self.subTest(url=url):
                validate_api_base_url(url)

    def test_missing_local_placeholder_and_credential_urls_are_rejected(self):
        for url in ("", " http://invalid", "https://api.studia.fr ", "http://api.studia.fr",
                    "https://localhost", "https://10.0.2.2:8000", "https://192.168.1.2",
                    "https://127.0.0.1", "https://[::1]", "https://api.local", "https://api.example",
                    "https://api.example.org", "https://<URL_REELLE_HTTPS>",
                    "https://name:secret@api.studia.fr", "https://api.studia.fr?key=secret",
                    "https://api.studia.fr#fragment", "https://api.studia.fr:wrong",
                    "https://api.studia.fr/docs/", "https://api.studia.fr/health", "https://api.studia.fr/api"):
            with self.subTest(url=url), self.assertRaises(ValueError):
                validate_api_base_url(url)

    def test_ci_counter_can_be_incremented_into_valid_android_version_code(self):
        for value in ("0", "1", "9999", "2099999999"):
            validate_build_number(value)
        for value in ("", "-1", "1.5", "abc", "2100000000", " 1"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                validate_build_number(value)


if __name__ == "__main__":
    unittest.main()
