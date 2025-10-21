import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:scriptagher/shared/config/api_base_url.dart';

import '../../models/bot.dart';
import '../../models/bot_filter.dart';
import '../../models/bot_navigation.dart';
import '../../services/bot_get_service.dart';
import '../../services/bot_upload_service.dart';
import '../components/app_gradient_background.dart';
import '../components/bot_card_component.dart';
import '../components/search_component.dart';
import '../components/feedback_banner.dart';
import 'bot_detail_view.dart';

class BotList extends StatefulWidget {
  const BotList({Key? key}) : super(key: key);

  @override
  State<BotList> createState() => _BotListState();
}

class _BotListState extends State<BotList>
    with SingleTickerProviderStateMixin {
  late final BotGetService _botGetService;
  BotUploadService? _botUploadService;

  late Map<BotCategory, Future<Map<String, List<Bot>>>> _categoryFutures;
  late final TabController _tabController;

  String? _baseUrl;
  bool _hasBackend = false;
  Object? _backendError;
  BotCategory _selectedCategory = BotCategory.online;
  bool _argumentsHandled = false;
  bool _isUploading = false;
  bool _isRefreshingOnline = false;
  BotFilter _activeFilter = const BotFilter();

  String? get _backendErrorMessage {
    final error = _backendError;
    if (error == null) {
      return null;
    }
    if (error is StateError) {
      return error.message;
    }
    return error.toString();
  }

  @override
  void initState() {
    super.initState();
    final resolvedBase = ApiBaseUrl.resolve();
    _baseUrl = resolvedBase;
    _hasBackend = resolvedBase != null && resolvedBase.isNotEmpty;

    try {
      _botGetService = BotGetService(baseUrl: resolvedBase);
    } on StateError catch (error) {
      _backendError = error;
      _botGetService = BotGetService.unavailable();
      _hasBackend = false;
    }

    if (_hasBackend) {
      _botUploadService = BotUploadService(baseUrl: resolvedBase);
    }

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
    if (!_hasBackend && category != BotCategory.online) {
      return 'Disponibile solo con un backend configurato (--dart-define=API_BASE_URL=<url>).';
    }

    switch (category) {
      case BotCategory.downloaded:
        return 'Nessun bot scaricato trovato.';
      case BotCategory.online:
        if (!_hasBackend && kIsWeb) {
          return 'Nessun bot pubblicato sul catalogo GitHub Pages.';
        }
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

  Widget _buildBackendBanner(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.secondaryContainer;
    final onColor = theme.colorScheme.onSecondaryContainer;
    final textTheme = theme.textTheme;
    final errorMessage = _backendErrorMessage;

    return Card(
      margin: EdgeInsets.zero,
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.cloud_off_outlined, color: onColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Funzionalità limitate',
                    style: textTheme.titleMedium?.copyWith(
                      color: onColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Esegui l\'app con --dart-define=API_BASE_URL=<url> per abilitare download, upload e avvio dei bot.',
              style: textTheme.bodyMedium?.copyWith(color: onColor),
            ),
            if (kIsWeb) ...[
              const SizedBox(height: 6),
              Text(
                'In questa anteprima web vengono mostrati solo i metadati pubblicati tramite GitHub Pages.',
                style: textTheme.bodySmall?.copyWith(color: onColor),
              ),
            ],
            if (errorMessage != null && errorMessage.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                errorMessage,
                style: textTheme.bodySmall?.copyWith(color: onColor),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryView(
    BotCategory category,
    EdgeInsets listPadding,
    EdgeInsetsGeometry cardMargin,
  ) {
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
          padding: listPadding,
          children: filteredData.entries.map((entry) {
            final language = entry.key;
            final bots = entry.value;

            return ExpansionTile(
              title: Text(language),
              childrenPadding: const EdgeInsets.only(bottom: 4),
              children: bots
                  .map(
                    (bot) => BotCard(
                      bot: bot,
                      margin: cardMargin,
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
    final mediaQuery = MediaQuery.of(context);
    final double width = mediaQuery.size.width;
    final bool isTablet = width < 900;
    final bool isPhone = width < 600;

    final EdgeInsets listPadding = EdgeInsets.symmetric(
      horizontal: isPhone ? 4 : (isTablet ? 8 : 16),
      vertical: isPhone ? 4 : 8,
    );
    final EdgeInsetsGeometry cardMargin = EdgeInsets.fromLTRB(
      isPhone ? 4 : (isTablet ? 8 : 16),
      0,
      isPhone ? 4 : (isTablet ? 8 : 16),
      isPhone ? 10 : (isTablet ? 12 : 16),
    );
    final EdgeInsets contentCardMargin = EdgeInsets.fromLTRB(
      isPhone ? 8 : (isTablet ? 12 : 16),
      0,
      isPhone ? 8 : (isTablet ? 12 : 16),
      isPhone ? 12 : (isTablet ? 18 : 24),
    );
    final EdgeInsets filterPadding = EdgeInsets.fromLTRB(
      isPhone ? 12 : (isTablet ? 16 : 24),
      isPhone ? 12 : 16,
      isPhone ? 12 : (isTablet ? 16 : 24),
      isPhone ? 12 : 16,
    );
    final EdgeInsets backendPadding = EdgeInsets.fromLTRB(
      isPhone ? 12 : (isTablet ? 16 : 24),
      16,
      isPhone ? 12 : (isTablet ? 16 : 24),
      isPhone ? 8 : 12,
    );
    final BorderRadius searchRadius = BorderRadius.circular(isPhone ? 16 : 20);
    final EdgeInsets searchInnerPadding = EdgeInsets.symmetric(
      horizontal: isPhone ? 10 : 12,
      vertical: isPhone ? 6 : 8,
    );
    final bool compactTabs = width < 720;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Bot'),
        centerTitle: isPhone,
        actions: [
          if (_selectedCategory == BotCategory.online)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isPhone ? 4 : 8),
              child: _buildRefreshAction(compact: isPhone),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: compactTabs,
          tabs: BotCategory.values
              .map((category) => Tab(text: _labelForCategory(category)))
              .toList(),
        ),
      ),
      body: AppGradientBackground(
        applyTopSafeArea: false,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            if (!_hasBackend) ...[
              Padding(
                padding: backendPadding,
                child: _buildBackendBanner(context),
              ),
            ],
            Padding(
              padding: filterPadding,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceVariant
                      .withOpacity(0.6),
                  borderRadius: searchRadius,
                ),
                child: Padding(
                  padding: searchInnerPadding,
                  child: SearchView(
                    onFilterChanged: _handleFilterChanged,
                    hintText:
                        'Cerca per nome, tag, lingua o usa filtri (es. lang:python #utility)',
                  ),
                ),
              ),
            ),
            Expanded(
              child: Card(
                margin: contentCardMargin,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isPhone ? 20 : 24),
                ),
                clipBehavior: Clip.antiAlias,
                child: TabBarView(
                  controller: _tabController,
                  children: BotCategory.values
                      .map(
                        (category) => _buildCategoryView(
                          category,
                          listPadding,
                          cardMargin,
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildUploadFab(compact: isPhone),
    );
  }

  Widget _buildRefreshAction({required bool compact}) {
    if (compact) {
      return IconButton(
        tooltip: _isRefreshingOnline ? 'Aggiornamento...' : 'Aggiorna catalogo',
        onPressed: _isRefreshingOnline ? null : _refreshOnlineBots,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isRefreshingOnline
              ? const SizedBox(
                  key: ValueKey('progress'),
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(
                  Icons.refresh_rounded,
                  key: ValueKey('icon'),
                ),
        ),
      );
    }

    return FilledButton.tonalIcon(
      onPressed: _isRefreshingOnline ? null : _refreshOnlineBots,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _isRefreshingOnline
            ? const SizedBox(
                key: ValueKey('progress'),
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(
                Icons.refresh_rounded,
                key: ValueKey('icon'),
              ),
      ),
      label: Text(_isRefreshingOnline ? 'Aggiornamento...' : 'Aggiorna'),
    );
  }

  Widget? _buildUploadFab({required bool compact}) {
    if (_selectedCategory != BotCategory.local) {
      return null;
    }

    final bool disabled = _isUploading || _botUploadService == null;
    final Widget icon = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _isUploading
          ? const SizedBox(
              key: ValueKey('progress'),
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(
              Icons.upload_file_rounded,
              key: ValueKey('icon'),
            ),
    );

    if (compact) {
      return FloatingActionButton(
        onPressed: disabled ? null : _showUploadOptions,
        tooltip: _isUploading ? 'Caricamento...' : 'Importa bot',
        child: icon,
      );
    }

    return FloatingActionButton.extended(
      onPressed: disabled ? null : _showUploadOptions,
      icon: icon,
      label: Text(_isUploading ? 'Caricamento...' : 'Importa bot'),
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
      _showFeedback('Errore durante l\'aggiornamento: $e', isError: true);
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
      _showFeedback('Errore durante la selezione del file: $e', isError: true);
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
    } on _StoragePermissionDeniedException {
      // Il feedback è già stato comunicato all'utente.
    } catch (e) {
      _showFeedback('Errore durante la selezione della cartella: $e',
          isError: true);
    }
  }

  Future<File> _zipDirectory(String directoryPath) async {
    await _requireStoragePermission(
      'Per comprimere la cartella è necessario consentire l\'accesso all\'archiviazione.',
    );
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

  Future<void> _requireStoragePermission(String failureMessage) async {
    if (!mounted) {
      throw const _StoragePermissionDeniedException();
    }

    if (!Platform.isAndroid) {
      return;
    }

    var status = await Permission.storage.status;
    if (status.isGranted || status.isLimited) {
      return;
    }

    status = await Permission.storage.request();
    if (status.isGranted || status.isLimited) {
      return;
    }

    final message = status.isPermanentlyDenied
        ? '$failureMessage Abilita l\'autorizzazione dalle impostazioni di sistema.'
        : failureMessage;
    _showFeedback(message, isError: true);
    throw const _StoragePermissionDeniedException();
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
    if (_botUploadService == null) {
      _showFeedback(
        'L\'importazione è disponibile solo con un backend configurato (--dart-define=API_BASE_URL=<url>).',
        isError: true,
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final bot = await _botUploadService!.uploadBotFile(
        stream: stream,
        length: length,
        filename: filename,
      );

      if (!mounted) return;

      _showFeedback('Bot "${bot.botName}" importato con successo.');
      _refreshCategory(BotCategory.local);
    } catch (e) {
      _showFeedback('Errore durante il caricamento: $e', isError: true);
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

  void _showFeedback(String message, {bool isError = false}) {
    if (!mounted) return;
    FeedbackBanner.show(
      context,
      message: message,
      isError: isError,
    );
  }
}

class _StoragePermissionDeniedException implements Exception {
  const _StoragePermissionDeniedException();
}
