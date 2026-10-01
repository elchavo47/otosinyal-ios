class BrandAssets {
  static const Map<String, String> logos = {
    'Alfa Romeo': 'assets/brands/alfa-romeo.png',
    'Audi': 'assets/brands/audi.png',
    'BMW': 'assets/brands/bmw.png',
    'Chevrolet': 'assets/brands/chevrolet.png',
    'Chrysler': 'assets/brands/chrysler.png',
    'Cupra': 'assets/brands/seat.png',
    'Citroën': 'assets/brands/citroen.png',
    'Dacia': 'assets/brands/dacia.png',
    'Daewoo': 'assets/brands/daewoo.png',
    'Dodge': 'assets/brands/dodge.png',
    'Fiat': 'assets/brands/fiat.png',
    'Ford': 'assets/brands/ford.png',
    'Honda': 'assets/brands/honda.png',
    'Hummer': 'assets/brands/hummer.png',
    'Hyundai': 'assets/brands/hyundai.png',
    'Infiniti': 'assets/brands/infiniti.png',
    'Jaguar': 'assets/brands/jaguar.png',
    'Jeep': 'assets/brands/jeep.png',
    'Kia': 'assets/brands/kia.png',
    'Land Rover': 'assets/brands/land-rover.png',
    'Lexus': 'assets/brands/lexus.png',
    'MINI': 'assets/brands/mini.png',
    'Mazda': 'assets/brands/mazda.png',
    'Mercedes-Benz': 'assets/brands/mercedes-benz.png',
    'Mitsubishi': 'assets/brands/mitsubishi.png',
    'Nissan': 'assets/brands/nissan.png',
    'Opel': 'assets/brands/opel.png',
    'Peugeot': 'assets/brands/peugeot.png',
    'Porsche': 'assets/brands/porsche.png',
    'Renault': 'assets/brands/renault.png',
    'Rover': 'assets/brands/rover.png',
    'Saab': 'assets/brands/saab.png',
    'Seat': 'assets/brands/seat.png',
    'Smart': 'assets/brands/smart.png',
    'Subaru': 'assets/brands/subaru.png',
    'Suzuki': 'assets/brands/suzuki.png',
    'Toyota': 'assets/brands/toyota.png',
    'Volkswagen': 'assets/brands/volkswagen.png',
    'Volvo': 'assets/brands/volvo.png',
    'Škoda': 'assets/brands/skoda.png',
  };
  static String? logoFor(String brand) {
    final direct = logos[brand];
    if (direct != null) return direct;
    final normalized = brand.trim().toLowerCase();
    for (final entry in logos.entries) {
      if (entry.key.toLowerCase() == normalized) return entry.value;
    }
    return null;
  }
}
