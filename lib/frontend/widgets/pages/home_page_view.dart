import 'package:flutter/material.dart';
import '../../models/bot_navigation.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final List<_Category> _categories = const [
    _Category(
      title: 'Scaricati',
      description:
          'Consulta i bot che hai già scaricato e salvato nel database locale.',
      icon: Icons.download_done_outlined,
      category: BotCategory.downloaded,
    ),
    _Category(
      title: 'Online',
      description:
          'Scopri i bot disponibili online tramite le API e scaricane di nuovi.',
      icon: Icons.cloud_outlined,
      category: BotCategory.online,
    ),
    _Category(
      title: 'Locali',
      description:
          'Gestisci i bot presenti direttamente nel filesystem della macchina.',
      icon: Icons.folder_outlined,
      category: BotCategory.local,
    ),
  ];

  final List<_SectionItem> _sections = const [
    _SectionItem(
      title: 'Tutorial',
      description: 'Impara a configurare Scriptagher con guide passo-passo',
      icon: Icons.menu_book_outlined,
      routeName: '/tutorial',
    ),
    _SectionItem(
      title: 'Marketplace',
      description: 'Esplora e installa bot creati dalla community',
      icon: Icons.storefront_outlined,
      routeName: '/marketplace',
    ),
    _SectionItem(
      title: 'Impostazioni',
      description: 'Gestisci preferenze, privacy e telemetria',
      icon: Icons.settings_outlined,
      routeName: '/settings',
    ),
  ];

  late final TabController _tabController;
  int _selectedIndex = 0;
  bool _isTabControllerUpdateFromNavigation = false;

  int get _totalDestinations => _categories.length + _sections.length;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _totalDestinations, vsync: this);
    _tabController.addListener(_handleTabSelection);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;

    setState(() {
      _selectedIndex = _tabController.index;
    });

    if (_isTabControllerUpdateFromNavigation) {
      _isTabControllerUpdateFromNavigation = false;
      return;
    }

    _handleSelection(_tabController.index);
  }

  void _onDestinationSelected(int index) {
    if (_selectedIndex == index) {
      _handleSelection(index);
      return;
    }
    setState(() {
      _selectedIndex = index;
      if (_tabController.index != index) {
        _isTabControllerUpdateFromNavigation = true;
        _tabController.index = index;
      }
    });

    _handleSelection(index);
  }

  void _openBots(BotCategory category) {
    Navigator.pushNamed(
      context,
      '/bots',
      arguments: BotListArguments(initialCategory: category),
    );
  }

  void _openSection(_SectionItem section) {
    Navigator.pushNamed(context, section.routeName);
  }

  void _handleSelection(int index) {
    if (index < _categories.length) {
      return;
    }

    final section = _sections[index - _categories.length];
    _openSection(section);
  }

  void _openTutorial() {
    Navigator.pushNamed(context, '/tutorial');
  }

  Widget _buildCategoryContent(int index) {
    if (index < _categories.length) {
      final category = _categories[index];
      return Padding(
        key: ValueKey(category.category),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(category.icon, size: 32, color: Colors.blueAccent),
                const SizedBox(width: 12),
                Text(
                  category.title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              category.description,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: ElevatedButton.icon(
                onPressed: () => _openBots(category.category),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Apri elenco'),
              ),
            ),
          ],
        ),
      );
    }

    final section = _sections[index - _categories.length];
    return Padding(
      key: ValueKey(section.routeName),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(section.icon, size: 32, color: Colors.blueAccent),
              const SizedBox(width: 12),
              Text(
                section.title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            section.description,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black54,
            ),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: ElevatedButton.icon(
              onPressed: () => _openSection(section),
              icon: const Icon(Icons.arrow_forward),
              label: Text('Apri ${section.title}'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'HOME - Cosa vuoi fare?',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _openTutorial,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.school_outlined,
                          color: Colors.blueAccent, size: 32),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Crea il tuo bot',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Segui il tutorial passo-passo per creare un bot sicuro compatibile con Scriptagher.',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: const [
                                Text(
                                  'Apri tutorial',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward, size: 18),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth >= 800) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        NavigationRail(
                          selectedIndex: _selectedIndex,
                          onDestinationSelected: _onDestinationSelected,
                          labelType: NavigationRailLabelType.all,
                          destinations: [
                            ..._categories.map(
                              (category) => NavigationRailDestination(
                                icon: Icon(category.icon),
                                selectedIcon: Icon(
                                  category.icon,
                                  color: Colors.blueAccent,
                                ),
                                label: Text(category.title),
                              ),
                            ),
                            ..._sections.map(
                              (section) => NavigationRailDestination(
                                icon: Icon(section.icon),
                                selectedIcon: Icon(
                                  section.icon,
                                  color: Colors.blueAccent,
                                ),
                                label: Text(section.title),
                              ),
                            ),
                          ],
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: _buildCategoryContent(_selectedIndex),
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TabBar(
                        controller: _tabController,
                        labelColor: Colors.blueAccent,
                        unselectedLabelColor: Colors.grey,
                        tabs: [
                          ..._categories.map((category) => Tab(text: category.title)),
                          ..._sections.map((section) => Tab(text: section.title)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: List.generate(
                            _totalDestinations,
                            _buildCategoryContent,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Category {
  final String title;
  final String description;
  final IconData icon;
  final BotCategory category;

  const _Category({
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
  });
}

class _SectionItem {
  final String title;
  final String description;
  final IconData icon;
  final String routeName;

  const _SectionItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.routeName,
  });
}
