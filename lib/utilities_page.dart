import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'utility_tools.dart';

class UtilitiesPage extends StatefulWidget {
  const UtilitiesPage({required this.isWide, required this.onBack, super.key});

  final bool isWide;
  final VoidCallback onBack;

  @override
  State<UtilitiesPage> createState() => _UtilitiesPageState();
}

class _UtilitiesPageState extends State<UtilitiesPage> {
  final _calculatorInput = TextEditingController();
  final _textInput = TextEditingController();
  final _jsonInput = TextEditingController();
  final _encodingInput = TextEditingController();
  final _unitInput = TextEditingController();
  final _colorInput = TextEditingController(text: '#6750A4');
  final _timestampInput = TextEditingController();
  final Map<String, String> _results = {};

  UtilityUnitCategory _unitCategory = UtilityUnitCategory.length;
  String _fromUnit = 'Meters';
  String _toUnit = 'Kilometers';
  bool _includePasswordSymbols = true;
  double _passwordLength = 20;
  String? _colorError;

  static const _unitOptions = <UtilityUnitCategory, List<String>>{
    UtilityUnitCategory.length: [
      'Millimeters',
      'Centimeters',
      'Meters',
      'Kilometers',
      'Inches',
      'Feet',
      'Miles',
    ],
    UtilityUnitCategory.weight: [
      'Milligrams',
      'Grams',
      'Kilograms',
      'Ounces',
      'Pounds',
    ],
    UtilityUnitCategory.temperature: ['Celsius', 'Fahrenheit', 'Kelvin'],
    UtilityUnitCategory.volume: [
      'Milliliters',
      'Liters',
      'Cups (US)',
      'Pints (US)',
      'Gallons (US)',
    ],
  };

  @override
  void dispose() {
    _calculatorInput.dispose();
    _textInput.dispose();
    _jsonInput.dispose();
    _encodingInput.dispose();
    _unitInput.dispose();
    _colorInput.dispose();
    _timestampInput.dispose();
    super.dispose();
  }

  void _run(String key, String Function() action) {
    setState(() {
      try {
        _results[key] = action();
      } on FormatException catch (error) {
        _results[key] = 'Error: ${error.message}';
      } on ArgumentError catch (error) {
        _results[key] = 'Error: ${error.message}';
      } on Exception catch (error) {
        _results[key] = 'Error: $error';
      }
    });
  }

  Future<void> _copyResult(String key) async {
    final value = _results[key];
    if (value == null || value.startsWith('Error:')) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
  }

  Widget _result(String key) {
    final value = _results[key];
    if (value == null) return const SizedBox.shrink();
    final isError = value.startsWith('Error:');
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError
            ? colors.errorContainer
            : colors.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                color: isError ? colors.onErrorContainer : colors.onSurface,
              ),
            ),
          ),
          if (!isError)
            IconButton(
              tooltip: 'Copy result',
              onPressed: () => _copyResult(key),
              icon: const Icon(Icons.copy_rounded, size: 18),
            ),
        ],
      ),
    );
  }

  Widget _toolCard({
    required String title,
    required String description,
    required IconData icon,
    required Widget child,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: ExpansionTile(
        leading: Icon(icon, color: colors.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(description),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [child],
      ),
    );
  }

  Widget _input(
    TextEditingController controller, {
    String label = 'Enter text',
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }

  Widget _actionButton(String label, VoidCallback onPressed, {IconData? icon}) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.play_arrow_rounded),
      label: Text(label),
    );
  }

  Widget _calculatorTool() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _input(
        _calculatorInput,
        label: 'Expression (for example: (12 + 8) / 4)',
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
      ),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerLeft,
        child: _actionButton(
          'Calculate',
          () => _run(
            'calculator',
            () => UtilityTools.calculate(_calculatorInput.text).toString(),
          ),
          icon: Icons.calculate_outlined,
        ),
      ),
      _result('calculator'),
    ],
  );

  Widget _textTool() {
    final text = _textInput.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _textInput,
          maxLines: 5,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Type or paste text',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${text.length} characters  •  ${UtilityTools.countWords(text)} words  •  '
          '${text.isEmpty ? 0 : text.split('\n').length} lines',
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _actionButton(
              'UPPERCASE',
              () => _run('text', () => text.toUpperCase()),
            ),
            _actionButton(
              'lowercase',
              () => _run('text', () => text.toLowerCase()),
            ),
            _actionButton(
              'Title Case',
              () => _run('text', () => UtilityTools.titleCase(text)),
            ),
            _actionButton(
              'Reverse',
              () => _run(
                'text',
                () => String.fromCharCodes(text.runes.toList().reversed),
              ),
            ),
          ],
        ),
        _result('text'),
      ],
    );
  }

  Widget _jsonTool() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _input(_jsonInput, label: 'JSON input', maxLines: 6),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        children: [
          _actionButton(
            'Format',
            () => _run('json', () => UtilityTools.formatJson(_jsonInput.text)),
            icon: Icons.format_align_left_rounded,
          ),
          _actionButton(
            'Minify',
            () => _run(
              'json',
              () => UtilityTools.formatJson(_jsonInput.text, pretty: false),
            ),
            icon: Icons.compress_rounded,
          ),
        ],
      ),
      _result('json'),
    ],
  );

  Widget _encodingTool() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _input(_encodingInput, label: 'Text to encode or decode', maxLines: 3),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _actionButton(
            'Base64 encode',
            () => _run(
              'encoding',
              () => UtilityTools.encodeBase64(_encodingInput.text),
            ),
          ),
          _actionButton(
            'Base64 decode',
            () => _run(
              'encoding',
              () => UtilityTools.decodeBase64(_encodingInput.text),
            ),
          ),
          _actionButton(
            'URL encode',
            () => _run(
              'encoding',
              () => UtilityTools.encodeUrl(_encodingInput.text),
            ),
          ),
          _actionButton(
            'URL decode',
            () => _run(
              'encoding',
              () => UtilityTools.decodeUrl(_encodingInput.text),
            ),
          ),
        ],
      ),
      _result('encoding'),
    ],
  );

  Widget _unitTool() {
    final units = _unitOptions[_unitCategory]!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<UtilityUnitCategory>(
          initialValue: _unitCategory,
          decoration: const InputDecoration(
            labelText: 'Category',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(
              value: UtilityUnitCategory.length,
              child: Text('Length'),
            ),
            DropdownMenuItem(
              value: UtilityUnitCategory.weight,
              child: Text('Weight'),
            ),
            DropdownMenuItem(
              value: UtilityUnitCategory.temperature,
              child: Text('Temperature'),
            ),
            DropdownMenuItem(
              value: UtilityUnitCategory.volume,
              child: Text('Volume'),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            final nextUnits = _unitOptions[value]!;
            setState(() {
              _unitCategory = value;
              _fromUnit = nextUnits.first;
              _toUnit = nextUnits.length > 1 ? nextUnits[1] : nextUnits.first;
            });
          },
        ),
        const SizedBox(height: 10),
        _input(
          _unitInput,
          label: 'Value',
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _fromUnit,
                decoration: const InputDecoration(
                  labelText: 'From',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final unit in units)
                    DropdownMenuItem(value: unit, child: Text(unit)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _fromUnit = value);
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward_rounded),
            ),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _toUnit,
                decoration: const InputDecoration(
                  labelText: 'To',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final unit in units)
                    DropdownMenuItem(value: unit, child: Text(unit)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _toUnit = value);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: _actionButton(
            'Convert',
            () => _run('unit', () {
              final value = double.parse(_unitInput.text.trim());
              final result = UtilityTools.convertUnit(
                value,
                _unitCategory,
                _fromUnit,
                _toUnit,
              );
              return '$result $_toUnit';
            }),
            icon: Icons.swap_horiz_rounded,
          ),
        ),
        _result('unit'),
      ],
    );
  }

  Widget _colorTool() {
    Color? color;
    try {
      color = Color(UtilityTools.parseColor(_colorInput.text));
    } on FormatException {
      color = null;
    }
    final rgb = color == null
        ? null
        : 'RGB(${color.r.toInt()}, ${color.g.toInt()}, ${color.b.toInt()})';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _colorInput,
          onChanged: (_) => setState(() => _colorError = null),
          decoration: InputDecoration(
            labelText: 'Hex color',
            hintText: '#6750A4',
            errorText: _colorError,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color:
                        color ??
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(rgb ?? 'Enter a valid #RGB or #RRGGBB value'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: _actionButton('Convert', () {
                try {
                  final value = UtilityTools.parseColor(_colorInput.text);
                  final parsedColor = Color(value);
                  setState(() {
                    _colorError = null;
                    _results['color'] =
                        '#${value.toRadixString(16).substring(2).toUpperCase()}  '
                        'RGB(${parsedColor.r.toInt()}, ${parsedColor.g.toInt()}, '
                        '${parsedColor.b.toInt()})';
                  });
                } on FormatException catch (error) {
                  setState(() => _colorError = error.message);
                }
              }, icon: Icons.color_lens_outlined),
            ),
          ],
        ),
        _result('color'),
      ],
    );
  }

  Widget _passwordTool() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('Length: ${_passwordLength.round()} characters'),
      Slider(
        value: _passwordLength,
        min: 8,
        max: 64,
        divisions: 14,
        onChanged: (value) => setState(() => _passwordLength = value),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Include symbols'),
        value: _includePasswordSymbols,
        onChanged: (value) => setState(() => _includePasswordSymbols = value),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: _actionButton(
          'Generate password',
          () => _run(
            'password',
            () => UtilityTools.generatePassword(
              length: _passwordLength.round(),
              includeSymbols: _includePasswordSymbols,
            ),
          ),
          icon: Icons.password_rounded,
        ),
      ),
      _result('password'),
    ],
  );

  Widget _timestampTool() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _input(
        _timestampInput,
        label: 'Unix timestamp (seconds or milliseconds)',
        keyboardType: TextInputType.number,
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _actionButton(
            'Convert to date',
            () => _run('timestamp', () {
              final date = UtilityTools.unixTimestampToDateTime(
                _timestampInput.text,
              );
              return 'UTC: ${date.toIso8601String()}\n'
                  'Local: ${date.toLocal().toString()}';
            }),
            icon: Icons.event_outlined,
          ),
          _actionButton(
            'Use current time',
            () => setState(() {
              _timestampInput.text =
                  (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
              _results.remove('timestamp');
            }),
            icon: Icons.schedule_rounded,
          ),
        ],
      ),
      _result('timestamp'),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 24, 8),
          child: Row(
            children: [
              if (!widget.isWide)
                IconButton(
                  tooltip: 'Back',
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              Expanded(
                child: Text(
                  'Utilities',
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (widget.isWide) ...[
                const Icon(Icons.offline_bolt_outlined),
                const SizedBox(width: 8),
                Text(
                  'Works offline',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 24, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Handy tools that run locally on your device.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    _toolCard(
                      title: 'Calculator',
                      description: 'Arithmetic with parentheses and decimals',
                      icon: Icons.calculate_outlined,
                      child: _calculatorTool(),
                    ),
                    _toolCard(
                      title: 'Text toolkit',
                      description: 'Count, change case, and reverse text',
                      icon: Icons.text_fields_rounded,
                      child: _textTool(),
                    ),
                    _toolCard(
                      title: 'JSON formatter',
                      description: 'Validate, format, or minify JSON',
                      icon: Icons.data_object_rounded,
                      child: _jsonTool(),
                    ),
                    _toolCard(
                      title: 'Encoders and decoders',
                      description: 'Base64 and URL text conversion',
                      icon: Icons.code_rounded,
                      child: _encodingTool(),
                    ),
                    _toolCard(
                      title: 'Unit converter',
                      description: 'Length, weight, temperature, and volume',
                      icon: Icons.swap_horiz_rounded,
                      child: _unitTool(),
                    ),
                    _toolCard(
                      title: 'Color helper',
                      description: 'Preview hex colors and get RGB values',
                      icon: Icons.color_lens_outlined,
                      child: _colorTool(),
                    ),
                    _toolCard(
                      title: 'Password generator',
                      description: 'Create a random password on this device',
                      icon: Icons.password_rounded,
                      child: _passwordTool(),
                    ),
                    _toolCard(
                      title: 'Unix timestamp',
                      description: 'Convert a timestamp to UTC and local time',
                      icon: Icons.schedule_rounded,
                      child: _timestampTool(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
