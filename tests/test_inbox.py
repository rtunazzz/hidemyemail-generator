import unittest

from hidemyemail_generator.inbox import extract_verification_code


class VerificationCodeExtractionTests(unittest.TestCase):
    def test_extracts_chinese_verification_code(self):
        self.assertEqual(
            extract_verification_code(
                "你的 ChatGPT 临时验证码",
                "你的验证码是 937455。请勿告诉他人。",
            ),
            "937455",
        )

    def test_extracts_english_verification_code(self):
        self.assertEqual(
            extract_verification_code(
                "Verify your email",
                "Your verification code is AB12CD.",
            ),
            "AB12CD",
        )

    def test_ignores_year_in_security_notification(self):
        self.assertEqual(
            extract_verification_code(
                "New sign-in to your OpenAI account",
                "A sign-in happened on June 27, 2026.",
            ),
            "",
        )

    def test_ignores_uppercase_words_near_dates(self):
        self.assertEqual(
            extract_verification_code(
                "NGC API paths retiring September 30",
                "NVIDIA account notices can mention 2026 without containing a code.",
            ),
            "",
        )

    def test_ignores_plain_account_numbers(self):
        self.assertEqual(
            extract_verification_code(
                "Security alert for user",
                "Account 1067452334 signed in.",
            ),
            "",
        )


if __name__ == "__main__":
    unittest.main()
