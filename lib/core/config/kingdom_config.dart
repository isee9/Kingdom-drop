import 'package:flutter/material.dart';

/// ============================================================================
/// KINGDOM CONFIGURATION — the meta progression ladder
/// ============================================================================
///
/// Ten kingdoms, five upgrades each. Costs are held as plain data so the curve
/// can be rebalanced without touching progression logic, and the whole table
/// can be swapped for a JSON payload later (see [KingdomDefinition.fromJson])
/// once remote config exists.
///
/// Cost curve: kingdom N's upgrades are the base ladder scaled by
/// `1.0, 1.6, 2.4, 3.4, 4.6, 6.0, 7.6, 9.4, 11.4, 13.6`, rounded to the nearest
/// 5 crowns. That keeps kingdom 1 reachable in a handful of runs while making
/// the late kingdoms a genuine long-term goal.
abstract final class KingdomConfig {
  /// Upgrade costs for the first kingdom. Later kingdoms scale from these.
  static const List<int> _baseCosts = <int>[25, 40, 60, 90, 130];

  static const List<double> _kingdomScale = <double>[
    1.0,
    1.6,
    2.4,
    3.4,
    4.6,
    6.0,
    7.6,
    9.4,
    11.4,
    13.6,
  ];

  static int costFor(int kingdomIndex, int upgradeIndex) {
    final double scale = _kingdomScale[kingdomIndex.clamp(
      0,
      _kingdomScale.length - 1,
    )];
    final double raw = _baseCosts[upgradeIndex.clamp(0, _baseCosts.length - 1)] *
        scale;
    return (raw / 5).round() * 5;
  }

  /// Crowns paid out by the chest awarded for finishing a kingdom.
  static int completionCrowns(int kingdomIndex) => 25 + kingdomIndex * 15;

  static final List<KingdomDefinition> kingdoms = List<KingdomDefinition>
      .unmodifiable(
    <KingdomDefinition>[
      _build(
        0,
        id: 'forgotten_keep',
        name: 'Forgotten Keep',
        blurb: 'A ruin swallowed by ivy. Somewhere under it, a throne.',
        palette: const KingdomPalette(
          sky: <Color>[Color(0xFF3B2F6B), Color(0xFF6A4E8F)],
          ground: Color(0xFF2A2350),
          structure: Color(0xFF8B7FB5),
          structureLit: Color(0xFFC9BEE8),
          accent: Color(0xFFFFC53D),
        ),
        upgrades: const <String>[
          'Repair Castle Gate',
          'Repair Bridge',
          'Build Market',
          'Restore Tower',
          'Restore Castle',
        ],
      ),
      _build(
        1,
        id: 'greenwood_village',
        name: 'Greenwood Village',
        blurb: 'Good soil, good people, and a mill that has not turned in years.',
        palette: const KingdomPalette(
          sky: <Color>[Color(0xFF1F5E4A), Color(0xFF4CA07A)],
          ground: Color(0xFF23503F),
          structure: Color(0xFF9C7A52),
          structureLit: Color(0xFFE0BE8F),
          accent: Color(0xFF8CE6A8),
        ),
        upgrades: const <String>[
          'Clear the Overgrowth',
          'Raise the Mill',
          'Plant the Orchard',
          'Build the Longhouse',
          'Crown the Greenwood',
        ],
      ),
      _build(
        2,
        id: 'storm_harbour',
        name: 'Storm Harbour',
        blurb: 'The tide takes what it likes. Time to take some of it back.',
        palette: const KingdomPalette(
          sky: <Color>[Color(0xFF1B3E6B), Color(0xFF3E7BA8)],
          ground: Color(0xFF16324F),
          structure: Color(0xFF7A93AD),
          structureLit: Color(0xFFCADCEB),
          accent: Color(0xFF56D6FF),
        ),
        upgrades: const <String>[
          'Rebuild the Quay',
          'Light the Beacon',
          'Repair the Sea Wall',
          'Launch the Fleet',
          'Raise the Harbour Keep',
        ],
      ),
      _build(
        3,
        id: 'desert_citadel',
        name: 'Desert Citadel',
        blurb: 'Sand buried it once. It will not get a second chance.',
        palette: const KingdomPalette(
          sky: <Color>[Color(0xFF7A4A2B), Color(0xFFE0A050)],
          ground: Color(0xFF6B4626),
          structure: Color(0xFFD9B27C),
          structureLit: Color(0xFFFFE7BE),
          accent: Color(0xFFFFD166),
        ),
        upgrades: const <String>[
          'Unbury the Road',
          'Dig the Great Well',
          'Raise the Sun Gate',
          'Build the Bazaar',
          'Crown the Citadel',
        ],
      ),
      _build(
        4,
        id: 'frozen_kingdom',
        name: 'Frozen Kingdom',
        blurb: 'Everything here is preserved, including the grudges.',
        palette: const KingdomPalette(
          sky: <Color>[Color(0xFF2C4E77), Color(0xFF8FC5E8)],
          ground: Color(0xFF3E6389),
          structure: Color(0xFFBCD8EE),
          structureLit: Color(0xFFF2FAFF),
          accent: Color(0xFF7FE8FF),
        ),
        upgrades: const <String>[
          'Break the Ice Road',
          'Rekindle the Hearths',
          'Rebuild the Frost Wall',
          'Raise the Glass Spire',
          'Thaw the Throne Room',
        ],
      ),
      _build(
        5,
        id: 'haunted_realm',
        name: 'Haunted Realm',
        blurb: 'The old residents never left. They can be reasoned with.',
        palette: const KingdomPalette(
          sky: <Color>[Color(0xFF2A1B3D), Color(0xFF5B3A72)],
          ground: Color(0xFF241735),
          structure: Color(0xFF6E5A87),
          structureLit: Color(0xFFB79DD6),
          accent: Color(0xFF9DFFB0),
        ),
        upgrades: const <String>[
          'Mend the Iron Fence',
          'Relight the Lanterns',
          'Restore the Chapel',
          'Silence the Bell Tower',
          'Reclaim the Manor',
        ],
      ),
      _build(
        6,
        id: 'sky_kingdom',
        name: 'Sky Kingdom',
        blurb: 'Islands adrift, held up by nothing but very good engineering.',
        palette: const KingdomPalette(
          sky: <Color>[Color(0xFF3D5AA8), Color(0xFF9FC4FF)],
          ground: Color(0xFF44639E),
          structure: Color(0xFFCFDCFF),
          structureLit: Color(0xFFFFFFFF),
          accent: Color(0xFFFFE9A8),
        ),
        upgrades: const <String>[
          'Anchor the Drifting Isle',
          'Build the Skybridge',
          'Raise the Wind Mill',
          'Open the Cloud Market',
          'Crown the Sky Palace',
        ],
      ),
      _build(
        7,
        id: 'volcanic_fortress',
        name: 'Volcanic Fortress',
        blurb: 'Built on a volcano, deliberately. The forges are worth it.',
        palette: const KingdomPalette(
          sky: <Color>[Color(0xFF5C1A22), Color(0xFFC2452B)],
          ground: Color(0xFF3A1218),
          structure: Color(0xFF7C4038),
          structureLit: Color(0xFFFF9155),
          accent: Color(0xFFFFB443),
        ),
        upgrades: const <String>[
          'Channel the Lava Flow',
          'Fire the Great Forge',
          'Cast the Iron Gate',
          'Raise the Ash Tower',
          'Seal the Caldera Keep',
        ],
      ),
      _build(
        8,
        id: 'crystal_empire',
        name: 'Crystal Empire',
        blurb: 'Every wall sings a different note when the wind hits it.',
        palette: const KingdomPalette(
          sky: <Color>[Color(0xFF34246B), Color(0xFF8E5BD4)],
          ground: Color(0xFF2C1F5A),
          structure: Color(0xFFB79BFF),
          structureLit: Color(0xFFEFE2FF),
          accent: Color(0xFF6BF0FF),
        ),
        upgrades: const <String>[
          'Mine the First Shard',
          'Grow the Prism Grove',
          'Build the Refractory',
          'Raise the Singing Spire',
          'Set the Crystal Crown',
        ],
      ),
      _build(
        9,
        id: 'star_kingdom',
        name: 'Star Kingdom',
        blurb: 'The last one. Build it and the whole map looks up.',
        palette: const KingdomPalette(
          sky: <Color>[Color(0xFF120C33), Color(0xFF3B2A7A)],
          ground: Color(0xFF171040),
          structure: Color(0xFF6C5CE7),
          structureLit: Color(0xFFFFE9A8),
          accent: Color(0xFFFFC53D),
        ),
        upgrades: const <String>[
          'Chart the Constellations',
          'Build the Observatory',
          'Raise the Comet Gate',
          'Ignite the Star Forge',
          'Crown the Star Throne',
        ],
      ),
    ],
  );

  static KingdomDefinition _build(
    int index, {
    required String id,
    required String name,
    required String blurb,
    required KingdomPalette palette,
    required List<String> upgrades,
  }) {
    return KingdomDefinition(
      index: index,
      id: id,
      name: name,
      blurb: blurb,
      palette: palette,
      upgrades: List<KingdomUpgrade>.unmodifiable(<KingdomUpgrade>[
        for (int i = 0; i < upgrades.length; i++)
          KingdomUpgrade(
            index: i,
            name: upgrades[i],
            cost: costFor(index, i),
          ),
      ]),
    );
  }

  static int get kingdomCount => kingdoms.length;

  static KingdomDefinition byIndex(int index) =>
      kingdoms[index.clamp(0, kingdoms.length - 1)];

  /// Total crowns needed to finish every kingdom. Useful for balance checks.
  static int get totalCrownCost => kingdoms.fold(
    0,
    (int sum, KingdomDefinition k) =>
        sum + k.upgrades.fold(0, (int s, KingdomUpgrade u) => s + u.cost),
  );
}

/// A kingdom and its upgrade ladder.
@immutable
class KingdomDefinition {
  const KingdomDefinition({
    required this.index,
    required this.id,
    required this.name,
    required this.blurb,
    required this.palette,
    required this.upgrades,
  });

  /// Parses the same shape this class serialises to, so the table can move to
  /// a JSON asset or remote config without changing any consumer.
  factory KingdomDefinition.fromJson(Map<String, dynamic> json) {
    return KingdomDefinition(
      index: json['index'] as int,
      id: json['id'] as String,
      name: json['name'] as String,
      blurb: json['blurb'] as String? ?? '',
      palette: KingdomPalette.fromJson(
        json['palette'] as Map<String, dynamic>,
      ),
      upgrades: <KingdomUpgrade>[
        for (final dynamic u in json['upgrades'] as List<dynamic>)
          KingdomUpgrade.fromJson(u as Map<String, dynamic>),
      ],
    );
  }

  final int index;
  final String id;
  final String name;
  final String blurb;
  final KingdomPalette palette;
  final List<KingdomUpgrade> upgrades;

  int get upgradeCount => upgrades.length;

  int get totalCost =>
      upgrades.fold(0, (int sum, KingdomUpgrade u) => sum + u.cost);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'index': index,
    'id': id,
    'name': name,
    'blurb': blurb,
    'palette': palette.toJson(),
    'upgrades': <Map<String, dynamic>>[
      for (final KingdomUpgrade u in upgrades) u.toJson(),
    ],
  };
}

@immutable
class KingdomUpgrade {
  const KingdomUpgrade({
    required this.index,
    required this.name,
    required this.cost,
  });

  factory KingdomUpgrade.fromJson(Map<String, dynamic> json) => KingdomUpgrade(
    index: json['index'] as int,
    name: json['name'] as String,
    cost: json['cost'] as int,
  );

  final int index;
  final String name;
  final int cost;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'index': index,
    'name': name,
    'cost': cost,
  };
}

/// Colours the kingdom illustration is painted from. Keeping the art as a
/// palette plus vector code means a kingdom is a data row, not an asset
/// pipeline — and swapping in finished artwork later only touches the painter.
@immutable
class KingdomPalette {
  const KingdomPalette({
    required this.sky,
    required this.ground,
    required this.structure,
    required this.structureLit,
    required this.accent,
  });

  factory KingdomPalette.fromJson(Map<String, dynamic> json) => KingdomPalette(
    sky: <Color>[
      for (final dynamic v in json['sky'] as List<dynamic>) Color(v as int),
    ],
    ground: Color(json['ground'] as int),
    structure: Color(json['structure'] as int),
    structureLit: Color(json['structureLit'] as int),
    accent: Color(json['accent'] as int),
  );

  /// Two-stop vertical sky gradient.
  final List<Color> sky;
  final Color ground;

  /// Buildings that have not been restored yet.
  final Color structure;

  /// Buildings that have been restored.
  final Color structureLit;
  final Color accent;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'sky': <int>[for (final Color c in sky) c.toARGB32()],
    'ground': ground.toARGB32(),
    'structure': structure.toARGB32(),
    'structureLit': structureLit.toARGB32(),
    'accent': accent.toARGB32(),
  };
}
