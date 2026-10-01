class VagVehicleProfile {
  const VagVehicleProfile(this.id, this.brand, this.platform, this.model,
      this.chassis, this.firstYear, [this.lastYear]);

  final String id, brand, platform, model, chassis;
  final int firstYear;
  final int? lastYear;

  String get label => chassis.isEmpty ? model : '$model ($chassis)';
  bool supportsYear(int year) =>
      year >= firstYear && (lastYear == null || year <= lastYear!);
  List<int> years() {
    final limit = DateTime.now().year + 1;
    final end = lastYear == null || lastYear! > limit ? limit : lastYear!;
    return [for (var year = end; year >= firstYear; year--) year];
  }
}

class VagVehicleCatalog {
  static const vehicles = <VagVehicleProfile>[
    VagVehicleProfile('vw-golf7','Volkswagen','MQB','Golf VII','5G/AU',2012,2020),
    VagVehicleProfile('vw-passatb8','Volkswagen','MQB','Passat B8','3G',2014,2023),
    VagVehicleProfile('vw-tiguan2','Volkswagen','MQB','Tiguan II','AD/BW',2016,2023),
    VagVehicleProfile('vw-arteon','Volkswagen','MQB','Arteon','3H',2017,2023),
    VagVehicleProfile('vw-troc','Volkswagen','MQB','T-Roc','A1',2017),
    VagVehicleProfile('vw-touran2','Volkswagen','MQB','Touran II','5T',2015),
    VagVehicleProfile('vw-golf8','Volkswagen','MQB-Evo','Golf VIII','CD',2019),
    VagVehicleProfile('vw-passatb9','Volkswagen','MQB-Evo','Passat B9','CJ',2023),
    VagVehicleProfile('vw-tiguan3','Volkswagen','MQB-Evo','Tiguan III','CT',2023),
    VagVehicleProfile('vw-multivant7','Volkswagen','MQB-Evo','Multivan T7','ST',2021),
    VagVehicleProfile('vw-id3','Volkswagen','MEB','ID.3','E1',2019),
    VagVehicleProfile('vw-id4','Volkswagen','MEB','ID.4','E2',2020),
    VagVehicleProfile('vw-id5','Volkswagen','MEB','ID.5','E3',2021),
    VagVehicleProfile('vw-idbuzz','Volkswagen','MEB','ID. Buzz','EB',2022),
    VagVehicleProfile('vw-polo6c','Volkswagen','PQ26','Polo V','6C',2014,2017),
    VagVehicleProfile('vw-golf5','Volkswagen','PQ35','Golf V','1K',2003,2008),
    VagVehicleProfile('vw-golf6','Volkswagen','PQ35','Golf VI','5K',2008,2013),
    VagVehicleProfile('vw-tiguan1','Volkswagen','PQ35','Tiguan I','5N',2007,2016),

    VagVehicleProfile('audi-a3-8v','Audi','MQB','A3','8V',2012,2020),
    VagVehicleProfile('audi-tt-8s','Audi','MQB','TT','8S',2014,2023),
    VagVehicleProfile('audi-q2','Audi','MQB','Q2','GA',2016),
    VagVehicleProfile('audi-a3-8y','Audi','MQB-Evo','A3','8Y',2020),
    VagVehicleProfile('audi-q4','Audi','MEB','Q4 e-tron','F4',2021),
    VagVehicleProfile('audi-a4-b9','Audi','MLB-Evo','A4','B9/8W',2015),
    VagVehicleProfile('audi-a5-f5','Audi','MLB-Evo','A5','F5',2016),
    VagVehicleProfile('audi-q5-fy','Audi','MLB-Evo','Q5','FY',2017),
    VagVehicleProfile('audi-q7-4m','Audi','MLB-Evo','Q7','4M',2015),
    VagVehicleProfile('audi-q8-4m','Audi','MLB-Evo','Q8','4M8',2018),

    VagVehicleProfile('skoda-octavia3','Škoda','MQB','Octavia III','5E/A7',2012,2020),
    VagVehicleProfile('skoda-superb3','Škoda','MQB','Superb III','3V',2015,2023),
    VagVehicleProfile('skoda-kodiaq1','Škoda','MQB','Kodiaq I','NS',2016,2024),
    VagVehicleProfile('skoda-karoq','Škoda','MQB','Karoq','NU',2017),
    VagVehicleProfile('skoda-octavia4','Škoda','MQB-Evo','Octavia IV','NX',2020),
    VagVehicleProfile('skoda-superb4','Škoda','MQB-Evo','Superb IV','B4',2023),
    VagVehicleProfile('skoda-kodiaq2','Škoda','MQB-Evo','Kodiaq II','PS',2023),
    VagVehicleProfile('skoda-enyaq','Škoda','MEB','Enyaq','NY',2020),
    VagVehicleProfile('skoda-fabia3','Škoda','PQ26','Fabia III','NJ',2014,2021),
    VagVehicleProfile('skoda-rapid','Škoda','PQ26','Rapid','NH',2012,2020),
    VagVehicleProfile('skoda-octavia2','Škoda','PQ35','Octavia II','1Z/A5',2004,2013),

    VagVehicleProfile('seat-leon3','Seat','MQB','Leon III','5F',2012,2020),
    VagVehicleProfile('seat-ateca','Seat','MQB','Ateca','KH',2016),
    VagVehicleProfile('seat-tarraco','Seat','MQB','Tarraco','KN',2018,2024),
    VagVehicleProfile('seat-leon4','Seat','MQB-Evo','Leon IV','KL',2020),
    VagVehicleProfile('seat-leon2','Seat','PQ35','Leon II','1P',2005,2012),
    VagVehicleProfile('cupra-formentor','Cupra','MQB-Evo','Formentor','KM',2020),
    VagVehicleProfile('cupra-born','Cupra','MEB','Born','K1',2021),
    VagVehicleProfile('porsche-cayenne3','Porsche','MLB-Evo','Cayenne III','9Y',2017),
  ];

  static List<String> get brands {
    final result = <String>[];
    for (final item in vehicles) {
      if (!result.contains(item.brand)) result.add(item.brand);
    }
    return result;
  }

  static String? canonicalBrand(String? raw) {
    if (raw == null) return null;
    final value=raw.toLowerCase().replaceAll('š','s');
    for(final brand in brands){if(brand.toLowerCase().replaceAll('š','s')==value)return brand;}
    return null;
  }

  static List<String> platformsFor(String brand) {
    const order = ['MQB','MQB-Evo','MEB','MLB-Evo','PQ26','PQ35'];
    return order.where((platform) => vehicles.any(
      (item) => item.brand == brand && item.platform == platform)).toList();
  }

  static List<VagVehicleProfile> modelsFor(String brand, String platform) =>
      vehicles.where((item) => item.brand == brand && item.platform == platform).toList();

  static VagVehicleProfile? find(String? id) {
    if (id == null) return null;
    for (final item in vehicles) {
      if (item.id == id) return item;
    }
    return null;
  }

  static int? modelYearFromVin(String? vin) {
    if (vin == null || vin.length != 17) return null;
    const codes = 'ABCDEFGHJKLMNPRSTVWXY123456789';
    final index = codes.indexOf(vin[9].toUpperCase());
    if (index < 0) return null;
    final base = 1980 + index;
    final current = DateTime.now().year + 1;
    var year = base;
    while (year + 30 <= current) year += 30;
    return year;
  }

  /// VIN reliably supplies manufacturer and model year, but not every VAG
  /// model/platform. Return candidates instead of pretending an exact match.
  static List<VagVehicleProfile> suggestionsForVin(String? vin, String? brand) {
    if (brand == null) return const [];
    final normalized = canonicalBrand(brand);
    if(normalized==null)return const [];
    final year = modelYearFromVin(vin);
    return vehicles.where((item) {
      final sameBrand = item.brand == normalized;
      return sameBrand && (year == null || item.supportsYear(year));
    }).toList(growable: false);
  }
}
