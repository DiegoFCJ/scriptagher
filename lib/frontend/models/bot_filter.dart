import 'bot.dart';

class BotFilter {
  final String searchTerm;
  final List<String> languages;
  final List<String> tags;
  final List<String> authors;
  final List<String> versions;

  const BotFilter({
    this.searchTerm = '',
    this.languages = const [],
    this.tags = const [],
    this.authors = const [],
    this.versions = const [],
  });

  bool get isEmpty =>
      searchTerm.trim().isEmpty &&
      languages.isEmpty &&
      tags.isEmpty &&
      authors.isEmpty &&
      versions.isEmpty;

  factory BotFilter.fromQuery(String query) {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const BotFilter();
    }

    final tokenRegExp =
        RegExp(r'(\w+:"[^"]+"|\w+:[^\s]+|#[^\s]+|"[^"]+"|\S+)');
    final matches = tokenRegExp.allMatches(normalizedQuery);

    final List<String> languages = [];
    final List<String> tags = [];
    final List<String> authors = [];
    final List<String> versions = [];
    final List<String> searchTerms = [];

    String _cleanValue(String value) {
      if (value.startsWith('"') && value.endsWith('"') && value.length >= 2) {
        return value.substring(1, value.length - 1);
      }
      return value;
    }

    void _addToken(String token) {
      if (token.startsWith('#')) {
        final value = token.substring(1).trim();
        if (value.isNotEmpty) {
          tags.add(value.toLowerCase());
        }
        return;
      }

      final separatorIndex = token.indexOf(':');
      if (separatorIndex > 0) {
        final key = token.substring(0, separatorIndex).toLowerCase();
        final rawValue = token.substring(separatorIndex + 1);
        final value = _cleanValue(rawValue).trim();
        if (value.isEmpty) {
          return;
        }
        switch (key) {
          case 'lang':
          case 'language':
            languages.add(value.toLowerCase());
            return;
          case 'tag':
          case 'tags':
            tags.add(value.toLowerCase());
            return;
          case 'author':
            authors.add(value.toLowerCase());
            return;
          case 'version':
            versions.add(value.toLowerCase());
            return;
        }
      }

      searchTerms.add(_cleanValue(token));
    }

    for (final match in matches) {
      final token = match.group(0);
      if (token == null || token.trim().isEmpty) continue;
      _addToken(token.trim());
    }

    final searchTerm = searchTerms.join(' ').trim();

    return BotFilter(
      searchTerm: searchTerm,
      languages: languages,
      tags: tags,
      authors: authors,
      versions: versions,
    );
  }

  bool matches(Bot bot) {
    if (languages.isNotEmpty &&
        !languages.any((lang) => bot.language.toLowerCase() == lang)) {
      return false;
    }

    if (tags.isNotEmpty) {
      final botTags = bot.tags.map((tag) => tag.toLowerCase()).toSet();
      for (final tag in tags) {
        if (!botTags.contains(tag)) {
          return false;
        }
      }
    }

    if (authors.isNotEmpty) {
      final author = (bot.author ?? '').toLowerCase();
      if (!authors.any((filterAuthor) => author.contains(filterAuthor))) {
        return false;
      }
    }

    if (versions.isNotEmpty) {
      final version = bot.version.toLowerCase();
      if (!versions.any((filterVersion) => version.contains(filterVersion))) {
        return false;
      }
    }

    final normalizedSearch = searchTerm.toLowerCase();
    if (normalizedSearch.isEmpty) {
      return true;
    }

    bool _matchesField(String? field) =>
        field != null && field.toLowerCase().contains(normalizedSearch);

    final tagMatch = bot.tags
        .map((tag) => tag.toLowerCase())
        .any((tag) => tag.contains(normalizedSearch));

    return _matchesField(bot.botName) ||
        _matchesField(bot.description) ||
        _matchesField(bot.language) ||
        _matchesField(bot.author) ||
        _matchesField(bot.version) ||
        tagMatch;
  }
}
