import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../template_provider.dart';
import '../models.dart';
import 'desktop_editor.dart';
import 'desktop_view.dart';

class DesktopHomePage extends StatefulWidget {
  const DesktopHomePage({super.key});

  @override
  State<DesktopHomePage> createState() => _DesktopHomePageState();
}

class _DesktopHomePageState extends State<DesktopHomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: NavigationView(
        appBar: const NavigationAppBar(
          title: Text('Thermal Template Editor'),
          automaticallyImplyLeading: false,
        ),
        pane: NavigationPane(
          selected: _currentIndex,
          onChanged: (i) => setState(() => _currentIndex = i),
          displayMode: PaneDisplayMode.minimal,
          items: [
            PaneItem(
              icon: const Icon(FluentIcons.home),
              title: const Text('Templates'),
              body: const _TemplatesGrid(),
            ),
            PaneItemSeparator(),
            PaneItem(
              icon: const Icon(FluentIcons.info),
              title: const Text('About'),
              body: const Center(
                child: Text('Thermal Printer Editor v2.0 - Fluent UI Edition'),
              ),
            ),
          ],
          footerItems: [
            PaneItemAction(
              icon: Icon(
                context.read<TemplateProvider>().isDarkMode
                    ? FluentIcons.sunny
                    : FluentIcons.contact_heart,
              ),
              title: Text(
                context.watch<TemplateProvider>().isDarkMode
                    ? 'Light Mode'
                    : 'Dark Mode',
              ),
              onTap: () {
                context.read<TemplateProvider>().toggleDarkMode();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplatesGrid extends StatelessWidget {
  const _TemplatesGrid();

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Your Templates'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.add),
              label: const Text('New Template'),
              onPressed: () => _createNewTemplate(context),
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.import),
              label: const Text('Import Template'),
              onPressed: () async {
                final provider = context.read<TemplateProvider>();
                final success = await provider.importTemplate();
                if (success && context.mounted) {
                  displayInfoBar(
                    context,
                    builder: (context, close) {
                      return const InfoBar(
                        title: Text('Success'),
                        content: Text('Template imported successfully.'),
                        severity: InfoBarSeverity.success,
                      );
                    },
                  );
                }
              },
            ),
          ],
        ),
      ),
      content: Consumer<TemplateProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: ProgressRing());
          }

          if (provider.templates.isEmpty) {
            return Container(
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(FluentIcons.page_list, size: 60),
                  const SizedBox(height: 12),
                  const Text('No templates found.'),
                  const SizedBox(height: 12),
                  Button(
                    child: const Text('Create New'),
                    onPressed: () => _createNewTemplate(context),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(24),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            itemCount: provider.templates.length,
            itemBuilder: (context, index) {
              final template = provider.templates[index];
              return _DesktopTemplateTile(template: template);
            },
          );
        },
      ),
    );
  }

  void _createNewTemplate(BuildContext context) {
    final id = const Uuid().v4();
    final newTemplate = TemplateModel(
      id: id,
      name: 'Template ${DateTime.now().millisecond}',
      widgets: [],
    );

    Navigator.push(
      context,
      FluentPageRoute(
        builder: (context) =>
            DesktopEditorPage(template: newTemplate, isNew: true),
      ),
    );
  }
}

class _DesktopTemplateTile extends StatelessWidget {
  final TemplateModel template;

  const _DesktopTemplateTile({required this.template});

  @override
  Widget build(BuildContext context) {
    return Card(
      padding: EdgeInsets.zero,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            FluentPageRoute(
              builder: (context) => DesktopViewPage(template: template),
            ),
          );
        },
        child: Column(
          children: [
            Expanded(
              child: Container(
                color: FluentTheme.of(context).cardColor,
                child: Center(
                  child: Icon(
                    FluentIcons.file_template,
                    size: 40,
                    color: Colors.blue,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(FluentIcons.edit),
                        onPressed: () {
                          Navigator.push(
                            context,
                            FluentPageRoute(
                              builder: (context) =>
                                  DesktopEditorPage(template: template),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(FluentIcons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Delete Template'),
        content: Text('Are you sure you want to delete "${template.name}"?'),
        actions: [
          Button(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          FilledButton(
            style: ButtonStyle(backgroundColor: ButtonState.all(Colors.red)),
            onPressed: () {
              Provider.of<TemplateProvider>(
                context,
                listen: false,
              ).deleteTemplate(template.id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
