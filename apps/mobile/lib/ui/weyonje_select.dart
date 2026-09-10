import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// A single selection with stable values, including when labels are duplicated.
class WeyonjeSelect<T> extends StatelessWidget {
  const WeyonjeSelect({
    required this.items,
    required this.onChanged,
    this.initialValue,
    this.label,
    this.validator,
    super.key,
  });

  final List<({T value, String label})> items;
  final ValueChanged<T?>? onChanged;
  final T? initialValue;
  final Widget? label;
  final FormFieldValidator<T>? validator;

  @override
  Widget build(BuildContext context) => FSelect<T>.rich(
    label: label,
    enabled: onChanged != null,
    control: FSelectControl.managed(initial: initialValue, onChange: onChanged),
    validator: validator ?? (_) => null,
    format: (value) => items.firstWhere((item) => item.value == value).label,
    children: [
      for (final item in items)
        FSelectItem(title: Text(item.label), value: item.value),
    ],
  );
}
