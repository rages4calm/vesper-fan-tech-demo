import os,tempfile,unittest,importlib.util,time
from pathlib import Path
from unittest.mock import patch
temporary=tempfile.TemporaryDirectory();os.environ['VESPER_HELPER_DATA']=temporary.name
import service

class Limits(unittest.TestCase):
    def setUp(self):
        service.KEY='unit-test-key';service.CONFIG.update(ai_enabled=True,daily_request_limit=2,daily_spend_limit_usd=.01,minimum_request_interval_seconds=0)
        service.ledger.update(requests=0,input_tokens=0,output_tokens=0,estimated_usd=0.,reserved_usd=0.)
        service.last_request=0;service.backoff_until=0;service.failures=0
        self.body={'state':{'name':'Test'},'options':{'rest':'Rest','work':'Work'},'fallback':'rest'}
    def test_no_key_uses_rules_without_network(self):
        service.KEY=''
        with patch('service.requests.post') as network:
            self.assertEqual(service.decide(self.body)['choice'],'rest');network.assert_not_called()
    def test_hard_request_limit(self):
        service.ledger['requests']=2
        with patch('service.requests.post') as network:
            self.assertIn('limit',service.decide(self.body)['reason']);network.assert_not_called()
    def test_spending_reservation_prevents_call(self):
        service.CONFIG['daily_spend_limit_usd']=0
        with patch('service.requests.post') as network:
            self.assertIn('limit',service.decide(self.body)['reason']);network.assert_not_called()
    def test_timeout_backoff_no_retry_storm(self):
        with patch('service.requests.post',side_effect=service.requests.Timeout):
            self.assertEqual(service.decide(self.body)['mode'],'rules fallback')
        with patch('service.requests.post') as network:
            self.assertEqual(service.decide(self.body)['reason'],'Cooldown');network.assert_not_called()
        self.assertEqual(service.ledger['requests'],1)
    def test_invalid_model_action_is_not_executed(self):
        class Response:
            ok=True
            def json(self):return {'answers':{'next':{'choice':'steal'}}}
        with patch('service.requests.post',return_value=Response()):
            self.assertEqual(service.decide(self.body)['choice'],'rest')
    def test_oversized_state_rejected_before_network(self):
        self.body['state']={'text':'x'*12000}
        with self.assertRaises(ValueError):service.decide(self.body)
    def test_success_settles_reservation_and_persists_usage(self):
        import json
        class Response:
            ok=True
            def json(self):return {'answers':{'next':{'choice':'work','confidence':.9}},'usage':{'input_tokens':400,'output_tokens':30},'model':'jev-test'}
        with patch('service.requests.post',return_value=Response()):
            self.assertEqual(service.decide(self.body)['choice'],'work')
        saved=json.loads(service.ledger_path.read_text())
        self.assertEqual(saved['requests'],1)
        self.assertEqual(saved['input_tokens'],400)
        self.assertAlmostEqual(saved['reserved_usd'],400*.042/1000000)
    def test_unknown_timeout_retains_spending_reservation(self):
        with patch('service.requests.post',side_effect=service.requests.Timeout):service.decide(self.body)
        self.assertGreater(service.ledger['reserved_usd'],0)
        self.assertEqual(service.ledger['estimated_usd'],0)

if __name__=='__main__':unittest.main()
