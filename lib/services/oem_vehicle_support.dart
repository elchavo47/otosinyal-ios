import '../models/vehicle.dart';
import 'package:otosinyal_obd2/l10n/tx.dart';

/// User-facing OEM diagnostic eligibility. This does NOT claim that every
/// manufacturer-specific signal works just because a model was selected.
/// Selection makes the vehicle eligible; live ECU identification must still
/// confirm the profile before OEM-only signals are presented as verified.
class OemVehicleSupport {
  static final Map<String, String> _groups = {
    'volkswagen': tx('Volkswagen Grubu'),
    'audi': tx('Volkswagen Grubu'),
    'skoda': tx('Volkswagen Grubu'),
    'škoda': tx('Volkswagen Grubu'),
    'seat': tx('Volkswagen Grubu'),
    'cupra': tx('Volkswagen Grubu'),
    'bmw': 'BMW Group',
    'mini': 'BMW Group',
    'mercedes': 'Mercedes-Benz',
    'mercedes-benz': 'Mercedes-Benz',
    'ford': 'Ford',
    'toyota': 'Toyota / Lexus',
    'lexus': 'Toyota / Lexus',
    'hyundai': 'Hyundai Motor Group',
    'kia': 'Hyundai Motor Group',
    'genesis': 'Hyundai Motor Group',
    'renault': 'Renault / Dacia',
    'dacia': 'Renault / Dacia',
    'peugeot': 'Stellantis',
    'citroen': 'Stellantis',
    'citroën': 'Stellantis',
    'ds': 'Stellantis',
    'opel': 'Stellantis',
    'vauxhall': 'Stellantis',
    'fiat': 'Stellantis',
    'alfa romeo': 'Stellantis',
    'jeep': 'Stellantis',
    'honda': 'Honda / Acura',
    'acura': 'Honda / Acura',
    'nissan': 'Nissan / Infiniti',
    'infiniti': 'Nissan / Infiniti',
    'mazda': 'Mazda',
    'mitsubishi': 'Mitsubishi',
    'subaru': 'Subaru',
    'suzuki': 'Suzuki',
    'volvo': 'Volvo',
    'porsche': 'Porsche',
    'land rover': 'JLR',
    'range rover': 'JLR',
    'jaguar': 'JLR',
  };

  static String _key(String value) => value.trim().toLowerCase();
  static bool isEligibleBrand(String brand) => _groups.containsKey(_key(brand));
  static bool isEligible(Vehicle? vehicle) => vehicle != null && isEligibleBrand(vehicle.brand);
  static String? groupFor(String brand) => _groups[_key(brand)];

  static String selectedVehicleMessage(Vehicle vehicle) {
    final group = groupFor(vehicle.brand);
    if (group == null) {
      return tx('Bu araçta standart OBD teşhisi kullanılabilir. Marka özel gelişmiş özellikler henüz doğrulanmış kapsamda değil.');
    }
    return tx('{0} gelişmiş teşhis kapsamına aday. OBD bağlantısından sonra OTOSİNYAL motor kontrol ünitesini doğrulayıp yalnızca gerçekten kullanılabilen özellikleri açacak.', [group]);
  }
}
