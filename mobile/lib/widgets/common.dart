import 'package:flutter/material.dart';

import '../models/models.dart';
import '../utils/format.dart';

Future<T?> go<T>(BuildContext context, Widget screen) =>
    Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => screen));
void toast(BuildContext context, String text, {bool error = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class PageBody extends StatelessWidget {
  final List<Widget> children;
  const PageBody({super.key, required this.children});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
    physics: const AlwaysScrollableScrollPhysics(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const SectionTitle(this.title, {super.key, this.subtitle, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 16),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  final String title, message;
  final IconData icon;
  const EmptyState(
    this.title,
    this.message, {
    super.key,
    this.icon = Icons.inventory_2_outlined,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
    child: Column(
      children: [
        Icon(icon, size: 44, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 14),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}

class RemoteView extends StatefulWidget {
  final Future<dynamic> Function() load;
  final Widget Function(dynamic data, Future<void> Function() reload) builder;
  const RemoteView({super.key, required this.load, required this.builder});
  @override
  State<RemoteView> createState() => _RemoteViewState();
}

class _RemoteViewState extends State<RemoteView> {
  late Future<dynamic> future;
  @override
  void initState() {
    super.initState();
    future = widget.load();
  }

  Future<void> reload() async {
    final next = widget.load();
    setState(() => future = next);
    try {
      await next;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: future,
    builder: (context, s) {
      if (s.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (s.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 40),
                const SizedBox(height: 16),
                Text(s.error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tekrar dene'),
                ),
              ],
            ),
          ),
        );
      }
      return RefreshIndicator(
        onRefresh: reload,
        child: widget.builder(s.data, reload),
      );
    },
  );
}

class StatusPill extends StatelessWidget {
  final String text;
  final bool alert;
  const StatusPill(this.text, {super.key, this.alert = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: alert
          ? const Color(0xFFFFE8DB)
          : Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: alert
            ? const Color(0xFF9B431B)
            : Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    ),
  );
}

class ProductTile extends StatelessWidget {
  final Json p;
  final VoidCallback? onTap;
  const ProductTile(this.p, {super.key, this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            Icons.inventory_2_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          p.s('name'),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text('${p.s('productCode')} • ${p.s('shelf')}'),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              quantity(p['quantity']),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: p.b('isCritical')
                    ? Colors.deepOrange
                    : Theme.of(context).colorScheme.primary,
              ),
            ),
            Text(p.s('measureUnit'), style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    ),
  );
}

class MovementTile extends StatelessWidget {
  final Json m;
  const MovementTile(this.m, {super.key});
  @override
  Widget build(BuildContext context) {
    final positive = m.n('quantity') > 0;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: positive
            ? const Color(0xFFDDF2EB)
            : const Color(0xFFFFE8DB),
        child: Icon(
          positive ? Icons.south_west : Icons.north_east,
          color: positive ? const Color(0xFF127455) : const Color(0xFF9B431B),
        ),
      ),
      title: Text(
        m.s('product', movementLabel(m.s('type'))),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${m.s('description')}\n${dateTime(m['createdAt'])}',
        maxLines: 3,
      ),
      trailing: Text(
        '${positive ? '+' : ''}${quantity(m['quantity'])}',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: positive ? const Color(0xFF127455) : const Color(0xFFB9562A),
        ),
      ),
    );
  }
}

class BusyButton extends StatelessWidget {
  final bool busy;
  final String label;
  final VoidCallback action;
  final IconData? icon;
  const BusyButton({
    super.key,
    required this.busy,
    required this.label,
    required this.action,
    this.icon,
  });
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: busy ? null : action,
    icon: busy
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon ?? Icons.check),
    label: Text(label),
  );
}

class ChoiceField extends StatelessWidget {
  final String label;
  final int? value;
  final List<Json> items;
  final String Function(Json) display;
  final void Function(int?) onChanged;
  final bool required;
  const ChoiceField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.display,
    required this.onChanged,
    this.required = true,
  });
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<int>(
    key: ValueKey('$label:$value'),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: items
        .map(
          (x) => DropdownMenuItem(
            value: x.n('id'),
            child: Text(
              display(x),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        )
        .toList(),
    onChanged: onChanged,
    validator: required ? (v) => v == null ? 'Bir seçim yapın.' : null : null,
  );
}
