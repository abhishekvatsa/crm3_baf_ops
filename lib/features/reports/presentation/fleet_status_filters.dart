part of 'fleet_status_screen.dart';

// Report scope uses the native identity of numbered assets and serial covers.

class _ReportFilters extends StatelessWidget {
  const _ReportFilters({
    required this.classes,
    required this.assets,
    required this.innerCovers,
    required this.assetClassId,
    required this.assetInstanceId,
    required this.startDate,
    required this.endDate,
    required this.onClassChanged,
    required this.onAssetChanged,
    required this.onDatesChanged,
  });

  final List<AssetClassRecord> classes;
  final List<AssetInstanceRecord> assets;
  final List<InnerCoverProfile> innerCovers;
  final String? assetClassId;
  final String? assetInstanceId;
  final DateTime startDate;
  final DateTime endDate;
  final ValueChanged<String?> onClassChanged;
  final ValueChanged<String?> onAssetChanged;
  final void Function(DateTime start, DateTime end) onDatesChanged;

  @override
  Widget build(BuildContext context) {
    final availableClasses = classes.where((item) => item.isActive).toList();
    final availableAssets = assets
        .where(
          (item) =>
              item.isActive &&
              (assetClassId == null || item.assetClassId == assetClassId),
        )
        .toList();
    final availableCovers =
        innerCovers
            .where(
              (cover) =>
                  availableClasses.any(
                    (item) =>
                        item.id == cover.assetClassId &&
                        item.legacyAssetTypeKey == 'innerCover',
                  ) &&
                  (assetClassId == null || cover.assetClassId == assetClassId),
            )
            .toList()
          ..sort((a, b) => a.serialNumber.compareTo(b.serialNumber));
    final selectedClassName = availableClasses
        .where((item) => item.id == assetClassId)
        .map((item) => item.name)
        .firstOrNull;
    final selectedAssetName = availableAssets
        .where((item) => item.id == assetInstanceId)
        .map((item) => '${item.assetClassName} ${item.assetNumber}')
        .firstOrNull;
    final selectedCoverName = availableCovers
        .where(
          (cover) =>
              '${OperationsReportSelection.innerCoverPrefix}${cover.id}' ==
              assetInstanceId,
        )
        .map((cover) => 'Inner Cover ${cover.serialNumber}')
        .firstOrNull;
    final scopeLabel =
        selectedCoverName ??
        selectedAssetName ??
        selectedClassName ??
        'All assets';
    final periodLabel =
        '${DateFormat('dd MMM').format(startDate)} - '
        '${DateFormat('dd MMM yyyy').format(endDate)}';

    return BafSectionSurface(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: false,
        leading: const Icon(Icons.tune_rounded, color: BafColors.cobalt),
        title: const Text(
          'Scope and period',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '$scopeLabel · $periodLabel',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(
          BafSpacing.md,
          0,
          BafSpacing.md,
          BafSpacing.md,
        ),
        children: [
          DropdownButtonFormField<String?>(
            key: ValueKey<String>('asset-class-${assetClassId ?? 'all'}'),
            initialValue: assetClassId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Asset class',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All asset classes'),
              ),
              ...availableClasses.map(
                (item) => DropdownMenuItem<String?>(
                  value: item.id,
                  child: Text(item.name, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: onClassChanged,
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            key: ValueKey<String>(
              'physical-asset-${assetClassId ?? 'all'}-'
              '${assetInstanceId ?? 'all'}',
            ),
            initialValue: assetInstanceId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Physical asset',
              prefixIcon: Icon(Icons.precision_manufacturing_outlined),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All assets in scope'),
              ),
              ...availableAssets.map(
                (item) => DropdownMenuItem<String?>(
                  value: item.id,
                  child: Text(
                    item.displayLabel,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              ...availableCovers.map(
                (cover) => DropdownMenuItem<String?>(
                  value:
                      '${OperationsReportSelection.innerCoverPrefix}${cover.id}',
                  child: Text(
                    'Inner Cover ${cover.serialNumber}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: onAssetChanged,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Start date',
                  value: startDate,
                  onTap: () async {
                    final date = await _pickDate(context, startDate);
                    if (date != null && !date.isAfter(endDate)) {
                      onDatesChanged(date, endDate);
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateField(
                  label: 'End date',
                  value: endDate,
                  onTap: () async {
                    final date = await _pickDate(context, endDate);
                    if (date != null && !date.isBefore(startDate)) {
                      onDatesChanged(startDate, date);
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PeriodButton(label: '7 days', onPressed: () => _applyDays(7)),
              _PeriodButton(label: '30 days', onPressed: () => _applyDays(30)),
              _PeriodButton(label: '90 days', onPressed: () => _applyDays(90)),
              _PeriodButton(
                label: 'This year',
                onPressed: () {
                  final now = DateTime.now();
                  onDatesChanged(
                    DateTime(now.year),
                    DateTime(now.year, now.month, now.day),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _applyDays(int days) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    onDatesChanged(end.subtract(Duration(days: days - 1)), end);
  }

  static Future<DateTime?> _pickDate(BuildContext context, DateTime current) =>
      showDatePicker(
        context: context,
        initialDate: current,
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      );
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(BafRadius.medium),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.calendar_today_outlined),
      ),
      child: Text(DateFormat('dd MMM yyyy').format(value)),
    ),
  );
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) =>
      OutlinedButton(onPressed: onPressed, child: Text(label));
}
