import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../models/bot.dart';
import '../../models/bot_filter.dart';
import '../../models/bot_navigation.dart';
import '../../services/bot_get_service.dart';
import '../../services/bot_upload_service.dart';
import '../components/bot_card_component.dart';
import '../components/search_component.dart';
import 'bot_detail_view.dart';

class BotList extends StatefulWidget {
  const BotList({Key? key}) : super(key: key);

  @override
  State<BotList> createState() => _BotListState();
}

class _BotListState extends State<BotList>
    with SingleTickerProviderStateMixin {
  final BotGetService _botGetService = BotGetService();
  final BotUploadService _botUploadService = BotUploadService();

  late Map<BotCategory, Future<Map<String, List<Bot>>>> _categoryFutures;
  late final TabController _tabController;

  BotCategory _selectedCategory = BotCategory.online;
  bool _argumentsHandled = false;
  bool _isUploading = false;
  bool _isRefreshingOnline = false;
  BotFilter _activeFilter = const BotFilter();

  @override
  void initState() {
    super.initState();
    _categoryFutures = {
      BotCategory.downloaded: _botGetService.fetchDownloadedBots(),
      BotCategory.online: _botGetService.fetchOnlineBots(),
      BotCategory.local: _botGetService.fetchLocalBots(),
    };
    _tabController = TabController(
      length: BotCategory.values.length,
      vsync: this,
      initialIndex: _selectedCategory.index,
    );
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _selectedCategory = BotCategory.values[_tabController.index];
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argumentsHandled) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is BotListArguments) {
      setState(() {
        _selectedCategory = args.initialCategory;
        _tabController.index = _selectedCategory.index;
      });
    }
    _argumentsHandled = true;
  }

  String _labelForCategory(BotCategory category) {
    switch (category) {
      case BotCategory.downloaded:
        return 'Scaricati';
      case BotCategory.online:
        return 'Online';
      case BotCategory.local:
        return 'Locali';
    }
  }

  String _emptyMessageForCategory(BotCategory category) {
    switch (category) {
      case BotCategory.downloaded:
        return 'Nessun bot scaricato trovato.';
      case BotCategory.online:
        return 'Nessun bot disponibile online al momento.';
      case BotCategory.local:
        return 'Nessun bot locale trovato.';
    }
  }

  void _handleFilterChanged(BotFilter filter) {
    setState(() {
      _activeFilter = filter;
    });
  }

  Map<String, List<Bot>> _filterBots(Map<String, List<Bot>> data) {
    return _botGetService.applyFilter(data, _activeFilter);
  }

  Widget _buildCategoryView(BotCategory category) {
    return FutureBuilder<Map<String, List<Bot>>>(
      future: _categoryFutures[category],
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Errore nel caricamento: ${snapshot.error}'),
          );
        }

        final data = snapshot.data ?? {};
        final filteredData = _filterBots(data);
        if (filteredData.isEmpty) {
          if (data.isEmpty) {
            return Center(child: Text(_emptyMessageForCategory(category)));
          }
          return const Center(
            child: Text('Nessun bot corrisponde ai filtri attivi.'),
          );
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          children: filteredData.entries.map((entry) {
            final language = entry.key;
            final bots = entry.value;

            return ExpansionTile(
              title: Text(language),
              children: bots
                  .map(
                    (bot) => BotCard(
                      bot: bot,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BotDetailView(bot: bot),
                          ),
                        );
                      },
                    ),
                  )
                  .toList(),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Bot'),
        actions: [
          if (_selectedCategory == BotCategory.online)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: TextButton.icon(
                onPressed:
                    _isRefreshingOnline ? null : () => _refreshOnlineBots(),
                icon: _isRefreshingOnline
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: Text(
                    _isRefreshingOnline ? 'Aggiornamento...' : 'Aggiorna'),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: BotCategory.values
              .map((category) => Tab(text: _labelForCategory(category)))
              .toList(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: SearchView(
              onFilterChanged: _handleFilterChanged,
              hintText:
                  'Cerca per nome, tag, lingua o usa filtri (es. lang:python #utility)',
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: BotCategory.values
                  .map(_buildCategoryView)
                  .toList(growable: false),
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedCategory == BotCategory.local
          ? FloatingActionButton.extended(
              onPressed: _isUploading ? null : _showUploadOptions,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isUploading
                    ? const SizedBox(
                        key: ValueKey('progress'),
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file, key: ValueKey('icon')),
              ),
              label: Text(_isUploading ? 'Caricamento...' : 'Importa bot'),
            )
          : null,
    );
  }

  Future<void> _refreshOnlineBots() async {
    setState(() {
      _isRefreshingOnline = true;
      _categoryFutures[BotCategory.online] =
          _botGetService.fetchOnlineBots(forceRefresh: true);
    });

    try {
      await _categoryFutures[BotCategory.online];
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante l\'aggiornamento: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isRefreshingOnline = false;
      });
    }
  }

  Future<void> _showUploadOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Seleziona archivio ZIP'),
              onTap: () {
                Navigator.of(context).pop();
                _pickZipFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Seleziona cartella'),
              onTap: () {
                Navigator.of(context).pop();
                _pickDirectory();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickZipFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: const ['zip'],
        withReadStream: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      final stream = _streamFromPlatformFile(file);
      await _performUpload(
        stream,
        file.size,
        file.name,
      );
    } catch (e) {
      _showSnackBar('Errore durante la selezione del file: $e', isError: true);
    }
  }

  Future<void> _pickDirectory() async {
    try {
      final directoryPath = await FilePicker.platform.getDirectoryPath();
      if (directoryPath == null) {
        return;
      }

      final zipFile = await _zipDirectory(directoryPath);
      try {
        final stream = zipFile.openRead();
        final length = await zipFile.length();
        await _performUpload(
          stream,
          length,
          p.basename(zipFile.path),
        );
      } finally {
        if (await zipFile.exists()) {
          await zipFile.delete();
        }
      }
    } catch (e) {
      _showSnackBar('Errore durante la selezione della cartella: $e',
          isError: true);
    }
  }

  Future<File> _zipDirectory(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      throw Exception('La cartella selezionata non esiste più.');
    }

    final archive = Archive();
    await for (final entity
        in directory.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final relativePath = p.relative(entity.path, from: directory.path);
        final bytes = await entity.readAsBytes();
        archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
      }
    }

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw Exception('La cartella selezionata è vuota.');
    }

    final tempDir = await getTemporaryDirectory();
    final zipPath =
        p.join(tempDir.path, '${p.basename(directory.path)}.zip');
    final zipFile = File(zipPath);
    await zipFile.writeAsBytes(encoded, flush: true);
    return zipFile;
  }

  Stream<List<int>> _streamFromPlatformFile(PlatformFile file) {
    if (file.readStream != null) {
      return file.readStream!;
    }
    if (file.bytes != null) {
      return Stream<List<int>>.value(file.bytes!);
    }
    if (file.path != null) {
      return File(file.path!).openRead();
    }
    throw Exception('Impossibile leggere il file selezionato.');
  }

  Future<void> _performUpload(
      Stream<List<int>> stream, int length, String filename) async {
    setState(() {
      _isUploading = true;
    });

    try {
      final bot = await _botUploadService.uploadBotFile(
        stream: stream,
        length: length,
        filename: filename,
      );

      if (!mounted) return;

      _showSnackBar('Bot "${bot.botName}" importato con successo.');
      _refreshCategory(BotCategory.local);
    } catch (e) {
      _showSnackBar('Errore durante il caricamento: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _refreshCategory(BotCategory category) {
    setState(() {
      switch (category) {
        case BotCategory.downloaded:
          _categoryFutures[category] = _botGetService.fetchDownloadedBots();
          break;
        case BotCategory.online:
          _categoryFutures[category] = _botGetService.fetchOnlineBots();
          break;
        case BotCategory.local:
          _categoryFutures[category] = _botGetService.fetchLocalBots();
          break;
      }
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }
}
