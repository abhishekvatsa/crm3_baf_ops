"""Pure setup safeguards; no service access or business acceptance."""
import unittest
from datetime import datetime, timezone
from unittest.mock import patch
import seed_ci_business_journeys as seed


class InnerCoverSeedSafeguardsTest(unittest.TestCase):
    def test_preexisting_record_aborts_before_any_new_write(self):
        with patch.object(seed, 'read', side_effect=[None, {'existing': True}]), \
             patch.object(seed, 'create') as create:
            with self.assertRaisesRegex(RuntimeError, 'preserving it without overwrite'):
                seed.seed_inner_cover_inventory({'token': 'synthetic-test-token'})
            create.assert_not_called()

    def test_all_readbacks_use_operations_and_timestamp_identity(self):
        documents = {'asset_classes/synthetic': {'version': 1,
                     'updatedAt': datetime(2026, 10, 3, tzinfo=timezone.utc)}}
        # Firestore may omit zero fractional digits; compare timestamp identity.
        with patch.object(seed, 'inner_cover_fixture_documents', return_value=documents), \
             patch.object(seed, 'read', side_effect=[None, {'version': 1,
                 'updatedAt': '2026-10-03T00:00:00.000000Z'}]) as read, \
             patch.object(seed, 'create') as create:
            seed.seed_inner_cover_inventory({'token': 'synthetic-test-token'})
            self.assertEqual(read.call_args.args, ('asset_classes/synthetic', 'synthetic-test-token'))
            self.assertEqual(create.call_count, 1)

    def test_readback_mismatch_stops_without_repairing_existing_data(self):
        documents = {'asset_classes/one': {'version': 1},
                     'asset_classes/two': {'version': 1}}
        with patch.object(seed, 'inner_cover_fixture_documents', return_value=documents), \
             patch.object(seed, 'read', side_effect=[None, None, {'version': 2}]), \
             patch.object(seed, 'create') as create:
            with self.assertRaisesRegex(RuntimeError, 'readback mismatch'):
                seed.seed_inner_cover_inventory({'token': 'synthetic-test-token'})
            self.assertEqual(create.call_count, 1)


if __name__ == '__main__':
    unittest.main()
