import unittest
from probe import parse_quotes

class QuoteTests(unittest.TestCase):
    def data(self):
        return {'BTCUSD': {'code':'BTC','codein':'USD','bid':'80740','timestamp':'1000'}, 'USDBRL': {'code':'USD','codein':'BRL','bid':'5.4597','timestamp':'1000'}}
    def test_valid(self):
        self.assertEqual(parse_quotes(self.data(), 2000)['usd'], 5.4597)
    def test_untrusted_quote_fields(self):
        for field, value in [('bid', '<img src="https://example.invalid/tracker">'), ('bid','nan'), ('bid','inf'), ('bid','-1'), ('timestamp','9999999999'), ('code','<b>BTC</b>')]:
            with self.subTest(field=field, value=value):
                data = self.data()
                data['BTCUSD'][field] = value
                with self.assertRaises(ValueError): parse_quotes(data, 2000)
    def test_missing_currency(self):
        data = self.data()
        del data['USDBRL']
        with self.assertRaises(KeyError): parse_quotes(data, 2000)
    def test_refresh_requests_again_and_updates_request_time(self):
        from unittest.mock import patch, MagicMock
        from probe import markets
        import json
        response = MagicMock()
        response.__enter__.return_value.read.return_value = json.dumps(self.data()).encode()
        opener = MagicMock()
        opener.open.return_value = response
        with patch('probe.urllib.request.build_opener', return_value=opener), patch('probe.time.time', side_effect=[2000, 2000, 2001, 2001]):
            first = markets()
            second = markets()
        self.assertEqual(opener.open.call_count, 2)
        self.assertEqual(first['requestedAt'], 2000000)
        self.assertEqual(second['requestedAt'], 2001000)
        self.assertEqual(first['btcTime'], second['btcTime'])
        self.assertEqual(second['btc'], 80740)
        self.assertEqual(second['usd'], 5.4597)

    def test_plain_text_sinks(self):
        from pathlib import Path
        qml = Path(__file__).with_name('Dashboard.qml').read_text()
        self.assertIn('textFormat: Text.PlainText', qml)
        self.assertIn('tooltipText: ""', qml)
        self.assertNotIn('notification', qml.lower())

if __name__ == '__main__': unittest.main()
