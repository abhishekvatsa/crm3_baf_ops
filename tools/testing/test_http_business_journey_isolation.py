import json
from pathlib import Path
import sys
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tool/dev'))
from http_journey import Journey, NoRedirect


class BusinessHttpIsolationTest(unittest.TestCase):
    def setUp(self):
        self.journey = Journey('demo-crm3-ci-journeys', 'hj-isolation-check',
                               Path('unused.json'), emulator_profile='isolated-ci')

    def test_refuses_live_project_and_wrong_profile_namespace(self):
        for project, profile in [('crm3-baf-ops-b8638', 'interactive'),
                                 ('demo-other', 'isolated-ci'), ('demo-test', 'unknown')]:
            with self.subTest(project=project, profile=profile), self.assertRaises(ValueError):
                Journey(project, 'hj-isolation-check', Path('unused.json'), emulator_profile=profile)

    def test_refuses_other_ports_projects_external_hosts_resets_and_redirects(self):
        j = self.journey
        for method, url in [('POST', j.functions.replace(':15001', ':5001') + '/read'),
                            ('GET', j.fs.replace('demo-crm3-ci-journeys', 'other') + '/x/y'),
                            ('GET', j.fs.replace('127.0.0.1', 'example.com') + '/x/y'),
                            ('GET', j.fs + '/x/y#fragment'),
                            ('DELETE', j.fs + '/x/y')]:
            with self.subTest(url=url), patch('http_journey.urllib.request.build_opener') as transport:
                with self.assertRaises(ValueError):
                    j.http(method, url)
                transport.assert_not_called()
        with self.assertRaises(ValueError):
            NoRedirect().redirect_request(None, None, 302, '', {}, 'https://example.com')

    def test_auth_posts_bind_exact_project_without_mutating_input(self):
        response = Mock()
        response.__enter__ = Mock(return_value=response)
        response.__exit__ = Mock(return_value=False)
        response.read.return_value = b'{}'
        payload = {'email': 'dev@example.invalid', 'targetProjectId': 'wrong'}
        with patch('http_journey.urllib.request.build_opener') as opener:
            opener.return_value.open.return_value = response
            self.journey.http('POST', self.journey.auth + '/accounts:signUp?key=emulator', payload)
        request = opener.return_value.open.call_args.args[0]
        self.assertEqual(json.loads(request.data)['targetProjectId'], self.journey.project)
        self.assertEqual(payload['targetProjectId'], 'wrong')

    def test_client_auth_sign_in_omits_admin_only_project_parameter(self):
        response = Mock()
        response.__enter__ = Mock(return_value=response)
        response.__exit__ = Mock(return_value=False)
        response.read.return_value = b'{}'
        with patch('http_journey.urllib.request.build_opener') as opener:
            opener.return_value.open.return_value = response
            self.journey.http('POST', self.journey.auth + '/accounts:signInWithPassword?key=emulator',
                              {'email': 'dev@example.invalid'}, token=None)
        request = opener.return_value.open.call_args.args[0]
        self.assertNotIn('targetProjectId', json.loads(request.data))
        self.assertFalse(request.has_header('Authorization'))
        with self.assertRaises(ValueError):
            self.journey.http('POST', self.journey.auth + '/accounts:signInWithPassword?key=emulator',
                              {'targetProjectId': self.journey.project}, token=None)


if __name__ == '__main__':
    unittest.main()
